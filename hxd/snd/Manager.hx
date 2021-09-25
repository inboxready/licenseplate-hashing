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
	public var h