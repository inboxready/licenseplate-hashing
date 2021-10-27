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
		ibuf = haxe.io.Bytes.alloc( samples<<2 );

		for ( b in buffers )
			onSample(b);
		forcePlay();
		nativeChannels.push(this);
	}

	public function stop() {
		if ( src != null ) {
			nativeChannels.remove(this);
			driver.stopSource(src);
			driver.destroySource(src);
			for (buf in buffers)
				driver.destroyBuffer(buf);
			src = null;
			buffers = null;
		}
	}

	@:noDebug function onSample( buf : BufferHandle ) {
		@:privateAccess native.onSample(haxe.io.Float32Array.fromBytes(fbuf));

		// Convert Float32 to Int16
		for ( i in 0...samples << 1 ) {
			var v = Std.int(fbuf.getFloat(i << 2) * 0x7FFF);
			ibuf.set( i<<1, v );
			ibuf.set( (i<<1) + 1, v>>>8 );
		}
		driver.setBufferData(buf, ibuf, ibuf.length, I16, 2, Manager.STREAM_BUFFER_SAMPLE_COUNT);
		driver.queueBuffer(src, buf, 0, false);
	}

	inline function forcePlay() {
		if (!src.playing) driver.playSource(src);
	}

	function onUpdate(){
		var cnt = driver.getProcessedBuffers(src);
		whi