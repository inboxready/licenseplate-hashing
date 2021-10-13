package hxd.snd;

import hxd.snd.Driver;
import haxe.MainLoop;

@:access(hxd.snd.Manager)
class Source {
	static var ID = 0;

	public var id (default, null) : Int;
	public var handle  : SourceHandle;
	public var channel : Channel;
	public var buffers : Array<Buffer>;

	public var volume  = -1.0;
	public var playing = false;
	public var start   = 0;

	public var streamSound : hxd.res.Sound;
	public var streamBuffer : haxe.io.Bytes;
	public var streamStart : Int;
	public var streamPos : Int;

	public function new(driver : Driver) {
		id      = ID++;
		handle  = driver.createSource();
		buffers = [];
	}

	public function dispose() {
		Manager.get().driver.destroySource(handle);
	}
}

@:access(hxd.snd.Manager)
class Buffer {
	public var handle   : BufferHandle;
	public var sound    : hxd.res.Sound;
	public var isEnd    : Bool;
	public var isStream : Bool;
	public var refs     : Int;
	public var lastStop : Float;

	public var start      : Int;
	public var end        : Int = 0;
	public var samples    : Int;
	public var sampleRate : Int;

	public function new(driver : Driver) {
		handle = driver.createBuffer();
		refs = 0;
		lastStop = haxe.Timer.stamp();
	}

	public function dispose() {
		Manager.get().driver.destroyBuffer(handle);
	}
}

class Manager {
	// Automatically set the channel to streaming mode if its duration exceed this value.
	public static var STREAM_DURATION            = 5.;
	public static var STREAM_BUFFER_SAMPLE_COUNT = 44100;
	public static var BUFFER_QUEUE_LENGTH        = 2;
	public static var MAX_SOURCES                = 16;
	public static var SOUND_BUFFER_CACHE_SIZE    = 256;
	public static var VIRTUAL_VOLUME_THRESHOLD   = 1e-5;

	/**
		Allows to decode big streaming buffers over X split frames. 0 to disable
	**/
	public static var BUFFER_STREAM_SPLIT        = 16;

	static var instance : Manager;

	public var masterVolume	: Float;
	public var masterSoundGroup   (default, null) : SoundGroup;
	public var masterChannelGroup (default, null) : ChannelGroup;
	public var listener : Listener;
	public var timeOffset : Float = 0.;

	var updateEvent   : MainEvent;

	var cachedBytes   : haxe.io.Bytes;
	var resampleBytes : haxe.io.Bytes;

	var driver   : Driver;
	var channels : Channel;
	var sources  : Array<Source>;
	var now      : Float;

	var soundBufferCount  : Int;
	var soundBufferMap    : Map<String, Buffer>;
	var soundBufferKeys	  : Array<String>;
	var freeStreamBuffers : Array<Buffer>;
	var effectGC          : Array<Effect>;
	var hasMasterVolume   : Bool;

	public var suspended : Bool = false;

	private function new() {
		try {
			#if usesys
			driver = new haxe.AudioTypes.SoundDriver();
			#elseif (js && !useal)
			driver = new hxd.snd.webaudio.Driver();
			#else
			driver = new hxd.snd.openal.Driver();
			#end
		} catch(e : String) {
			driver = null;
		}

		masterVolume       = 1.0;
		hasMasterVolume    = driver == null ? true : driver.hasFeature(MasterVolume);
		masterSoundGroup   = new SoundGroup  ("master");
		masterChannelGroup = new ChannelGroup("master");
		listener           = new Listener();
		soundBufferMap     = new Map();
		soundBufferKeys	   = [];
		freeStreamBuffers  = [];
		effectGC           = [];
		soundBufferCount   = 0;

		if (driver != null) {
			// alloc sources
			sources = [];
			for (i in 0...MAX_SOURCES) sources.push(new Source(driver));
		}

		cachedBytes   = haxe.io.Bytes.alloc(4 * 3 * 2);
		resampleBytes = haxe.io.Bytes.alloc(STREAM_BUFFER_SAMPLE_COUNT * 2);
	}

	function getTmpBytes(size) {
		if (cachedBytes.length < size)
			cachedBytes = haxe.io.Bytes.alloc(size);
		return cachedBytes;
	}

	function getResampleBytes(size : Int) {
		if (resampleBytes.length < size)
			resampleBytes = haxe.io.Bytes.alloc(size);
		return resampleBytes;
	}

	public static function get() : Manager {
		if( instance == null ) {
			instance = new Manager();
			instance.updateEvent = haxe.MainLoop.add(instance.update);
			#if (haxe_ver >= 4) instance.updateEvent.isBlocking = false; #end
		}
		return instance;
	}

	public function stopAll() {
		while( channels != null )
			channels.stop();
	}

	public function stopAllNotLooping() {
		var c = channels;
		while( c != null ) {
			var n = c.next;
			if( !c.loop ) c.stop();
			c = n;
		}
	}

	public function stopByName( name : String ) {
		var c = channels;
		while( c != null ) {
			var n = c.next;
			if( c.soundGroup != null && c.soundGroup.name == name ) c.stop();
			c = n;
		}
	}

	/**
		Returns iterator with all active instances of a Sound at the call time.
	**/
	public function getAll( sound : hxd.res.Sound ) : Iterator<Channel> {
		var ch = channels;
		var result = new Array<Channel>();
		while ( ch != null ) {
			if ( ch.sound == sound )
				result.push(ch);
			ch = ch.next;
		}
		return new hxd.impl.ArrayIterator(result);
	}

	public function cleanCache() {
		var i = 0;
		while (i < soundBufferKeys.length) {
			var k = soundBufferKeys[i];
			var b = soundBufferMap.get(k);
			i++;
			if (b.refs > 0) continue;
			soundBufferMap.remove(k);
			soundBufferKeys.remove(k);
			i--;
			b.dispose();
			--soundBufferCount;
		}
	}

	public function dispose() {
		stopAll();

		if (driver != null) {
			for (s in sources)           s.dispose();
			for (b in soundBufferMap)    b.dispose();
			for (b in freeStreamBuffers) b.dispose();
			for (e in effectGC)          e.driver.release();
			driver.dispose();
		}

		sources           = null;
		soundBufferMap    = null;
		soundBufferKeys   = null;
		freeStreamBuffers = null;
		effectGC          = null;

		updateEvent.stop();
		instance = null;
	}

	public function play(sound : hxd.res.Sound, ?channelGroup : ChannelGroup, ?soundGroup : SoundGroup) {
		if (soundGroup   == null) soundGroup   = masterSoundGroup;
		if (channelGroup == null) channelGroup = masterChannelGroup;

		var sdat = sound.getData();
		if( sdat.samples == 0 ) throw sound + " has no samples";

		var c = new Channel();
		c.sound        = sound;
		c.duration     = sdat.duration;
		c.manager      = this;
		c.soundGroup   = soundGroup;
		c.channelGroup = channelGroup;
		c.next         = channels;
		c.isLoading    = sdat.isLoading();
		c.isVirtual    = driver == null;
		c.lastStamp    = haxe.Timer.stamp();

		channels = c;
		return c;
	}

	function updateVirtualChannels(now : Float) {
		var c = channels;
		while (c != null) {
			if (c.pause || !c.isVirtual || c.isLoading) {
				c = c.next;
				continue;
			}

			c.position += Math.max(now - c.lastStamp, 0.0);
			c.lastStamp = now;

			var next = c.next; // save next, since we might release this channel
			while (c.position >= c.duration) {
				c.position -= c.duration;
				c.onEnd();

				// if we have released the next channel, let's stop here
				if( next != null && next.manager == null )
					next = null;

				if (c.queue.length > 0) {
					c.sound = c.queue.shift();
					c.duration = c.sound.getData().duration;
				} else if (!c.loop) {
					releaseChannel(c);
					break;
				}
			}

			c = next;
		}
	}

	public function update() {
		if( timeOffset != 0 ) {
			var c = channels;
			while( c != null ) {
				c.lastStamp += timeOffset;
				if( c.currentFade != null ) c.currentFade.start += timeOffset;
				c = c.next;
			}
			for( s in sources )
				for( b in s.buffers )
					b.lastStop += timeOffset;
			timeOffset = 0;
		}
		now = haxe.Timer.stamp();

		if (driver == null) {
			updateVirtualChannels(now);
			return;
		}

		// --------------------------------------------------------------------
		// (de)queue buffers, sync positions & release ended channels
		// --------------------------------------------------------------------

		for (s in sources) {
			var c = s.channel;
			if (c == null) continue;

			// did the user changed the position?
			if (c.positionChanged) {
				releaseSource(s);
				continue;
			}

			// process consumed buffers
			var lastBuffer = null;
			var count = driver.getProcessedBuffers(s.handle);
			for (i in 0...count) {
				var b = unqueueBuffer(s);
				if( b == null ) continue;
				lastBuffer = b;
				if (b.isEnd) {
					c.sound           = b.sound;
					c.duration        = b.sound.getData().duration;
					c.position        = c.duration;
					c.positionChanged = false;
					c.onEnd();
					s.start = 0;
				}
			}

			// did the source consumed all buffers?
			if (s.buffers.length == 0) {
				if (!lastBuffer.isEnd) {
					c.position = (lastBuffer.start + lastBuffer.samples) / lastBuffer.sampleRate;
					releaseSource(s);
				} else if (c.queue.length > 0) {
					c.sound    = c.queue.shift();
					c.duration = c.sound.getData().duration;
					c.position = 0;
					releaseSource(s);
				} else if (c.loop) {
					c.position = 0;
					releaseSource(s);
				} else {
					releaseChannel(c);
				}
				continue;
			}

			// sync channel position
			c.sound    = s.buffers[0].sound;
			c.duration = c.sound.getData().duration;

			var playedSamples = driver.getPlayedSampleCount(s.handle);
			if (playedSamples < 0)  {
				#if debug
				trace("playedSamples should positive : bug in driver");
				#end
				playedSamples = 0;
			}
			c.position = s.start / targetRate + playedSamples / s.buffers[0].sampleRate;
			c.positionChanged = false;

			// enqueue next buffers
			if (s.buffers.length < BUFFER_QUEUE_LENGTH) {
				var b = s.buffers[s.buffers.length - 1];
				if (!b.isEnd) {
					// next stream buffer
					queueBuffer(s, b.sound, b.start + b.samples);
				} else if (c.queue.length > 0) {
					// queue next sound buffer
					var snd = c.queue[0];
					if( queueBuffer(s, snd, 0) )
						c.queue.shift();
				} else if (c.loop) {
					// requeue last played sound
					queueBuffer(s, b.sound, 0);
				}
			}
		}

		// --------------------------------------------------------------------
		// calc audible volume & virtualize inaudible channels
		// --------------------------------------------------------------------

		var c = channels;
		while (c != null) {
			c.calcAudibleVolume(now);
			if( c.isLoading && !c.sound.getData().isLoading() )
				c.isLoading = false;
			c.isVirtual = suspended || c.pause || c.mute || c.channelGroup.mute || (c.allowVirtual && c.audibleVolume < VIRTUAL_VOLUME_THRESHOLD) || c.isLoading;
			c = c.next;
		}

		// --------------------------------------------------------------------
		// sort channels by priority
		// --------------------------------------------------------------------

		channels = haxe.ds.ListSort.sortSingleLinked(channels, sortChannel);

		// --------------------------------------------------------------------
		// virtualize sounds that puts the put the audible count over the maximum number of sources
		// --------------------------------------------------------------------

		var audibleCount = 0;
		var c = channels;
		while (c != null && !c.isVirtual) {
			if (++audibleCount > sources.length) c.isVirtual = true;
			else if (c.soundGroup.maxAudible >= 0) {
				if(c.soundGroup.lastUpdate != now) {
					c.soundGroup.lastUpdate = now;
					c.soundGroup.numAudible = 0;
				}
				if (++c.soundGroup.numAudible > c.soundGroup.maxAudible) {
					c.isVirtual = true;
					--audibleCount;
				}
			}
			c = c.next;
		}

		// --------------------------------------------------------------------
		// free sources that points to virtualized channels
		// --------------------------------------------------------------------

		for (s in sources) {
			if (s.channel == null || !s.channel.isVirtual) continue;
			releaseSource(s);
		}

		// --------------------------------------------------------------------
		// bind non-virtual channels to sources
		// --------------------------------------------------------------------

		var c = channels;
		while (c != null) {
			if (c.source != null || c.isVirtual) {
				c = c.next;
				continue;
			}

			// look for a free source
			var s = null;
			for (s2 in sources) if( s2.channel == null ) {
				s = s2;
				break;
			}

			if (s == null) throw "could not get a source";
			s.channel = c;
			c.source = s;

			checkTargetFormat(c.sound.getData(), c.soundGroup.mono);
			s.start = Math.floor(c.position * targetRate);
			if( s.start < 0 ) s.start = 0;
			queueBuffer(s, c.sound, s.start);
			c.positionChanged = false;
			c = c.next;
		}

		// --------------------------------------------------------------------
		// update source parameters
		// --------------------------------------------------------------------

		var usedEffects : Effect = null;
		var volume = hasMasterVolume ? 1. : masterVolume;
		for (s in sources) {
			var c = s.channel;
			if (c == null) continue;

			var v = c.currentVolume * volume;
			if (s.volume != v) {
				if (v < 0) v = 0;
				s.volume = v;
				driver.setSourceVolume(s.handle, v);
				#if hlopenal
				if( v > 1 ) Sys.println("Could not s