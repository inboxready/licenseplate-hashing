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