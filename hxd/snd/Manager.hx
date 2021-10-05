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
		