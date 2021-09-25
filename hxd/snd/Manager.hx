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

	public function