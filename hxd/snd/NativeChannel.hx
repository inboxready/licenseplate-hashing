package hxd.snd;

#if hlopenal

import openal.AL;
import hxd.snd.Manager;
import hxd.snd.Driver;

@:access(hxd.snd.Manager)
private class ALChannel {

	static var nativeUpdate : haxe.MainLoop.MainEvent;
	static var nativeChannels : Array<ALChannel>;

	static function updateChannels() {
		var i = 0;
		// Should ensure ordering if it was removed during update?
		for ( chn in nativeChannels ) chn.onUpdate();
	}

	var manager : Manager;
	var update : haxe.MainLoop.MainEvent;
	var native : NativeChannel;
	var samples : Int;

	var driver : Driver;
	var buffers : Array<BufferHandle>;
	var bufPos : Int;
	var src : SourceHandle;

	var fbuf : haxe.io.Bytes;
	var ibuf : haxe.io.Bytes;

	public function new(samples, native) {
		if ( nativeUpdate == null ) {
			nativeUpdate = haxe.MainLoop.add(updateChannels);
			#if (haxe_ver >= 4) nativeUpdate.isBlocking = false; #end
			nativeChannels = [];
		}
		this.native = native;
		this.samples = samples;

		this.manager = Manager.get();
		this.driver = manager.driver;

		buffers = [driver.createBuffer(), driver.createBuffer()];
		src = driver.createSource();
		bufPos = 0;

		// AL.sourcef(src,AL.PITCH,1.0);
		// AL.sourcef(src,AL.GAIN,1.0);
		fbuf = haxe.io.Bytes.alloc( samples<<3 );
		ibuf = haxe.io.Bytes.alloc( sampl