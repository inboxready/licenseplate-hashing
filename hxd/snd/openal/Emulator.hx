
package hxd.snd.openal;

private typedef F32 = Float;
private typedef Bytes = haxe.io.Bytes;

private class Channel extends NativeChannel {

	var source : Source;
	var startup = 0.;
	static inline var FADE_START = 10; // prevent clic at startup

	public function new(source, samples) {
		this.source = source;
		super(samples);
		#if js
		gain.gain.value = source.volume;
		#end
	}

	@:noDebug
	override function onSample( out : haxe.io.Float32Array ) {
		var pos = 0;
		var count = out.length >> 1;
		if( source.duration > 0 ) {
			var volume = #if js 1.0 #else source.volume #end;
			var bufferIndex = 0;
			var baseSample = 0;
			var curSample = source.currentSample;
			var buffer = source.buffers[bufferIndex++];
			while( count > 0 ) {
				while( buffer != null && curSample >= buffer.samples ) {
					baseSample += buffer.samples;
					curSample -= buffer.samples;
					buffer = source.buffers[bufferIndex++];
				}
				if( buffer == null ) {
					if( source.loop ) {
						curSample = 0;
						baseSample = 0;
						bufferIndex = 0;
						buffer = source.buffers[bufferIndex++];
						continue;
					}
					break;
				}
				var scount = buffer.samples - curSample;
				if( scount > count ) scount = count;
				var read = curSample << 1;
				var data = buffer.data;
				if( startup < 1 ) {
					for( i in 0...scount ) {
						out[pos++] = data[read++] * volume * startup;
						out[pos++] = data[read++] * volume * startup;
						if( startup < 1. ) {
							startup += 1 / FADE_START;
							if( startup > 1 ) startup = 1;
						}
					}
				} else {
					for( i in 0...scount ) {
						out[pos++] = data[read++] * volume;
						out[pos++] = data[read++] * volume;
					}
				}
				count -= scount;
				curSample += scount;
			}
			source.currentSample = baseSample + curSample;
			if( source.currentSample < 0 ) throw baseSample+"/" + curSample;
		}

		for( i in 0...count<<1 )
			out[pos++] = 0.;
	}

}

class Source {

	// Necessary to prevent stopping the channel while it's still playing
	// This seems related to some lag in NativeChannel creation and data delivery
	static inline var STOP_DELAY = #if js 200 #else 0 #end;

	public static var CHANNEL_BUFSIZE = #if js 8192 #else 4096 #end; /* 100 ms latency @44.1Khz */

	static var ID = 0;
	static var all = new Map<Int,Source>();

	public var id : Int;
	public var chan : hxd.snd.NativeChannel;

	public var playedTime = 0.;
	public var currentSample : Int = 0;
	public var buffers : Array<Buffer> = [];
	public var loop = false;
	public var volume : F32 = 1.;
	public var playing(get, never) : Bool;
	public var duration : Float;
	public var frequency : Int;

	public function new() {
		id = ++ID;
		all.set(id, this);
	}

	public function updateDuration() {
		frequency = buffers.length == 0 ? 1 : buffers[0].frequency;
		duration = 0.;
		for( b in buffers )
			duration += b.samples / b.frequency;
	}

	inline function get_playing() return chan != null;

	public function play() {
		if( chan == null ) {
			playedTime = haxe.Timer.stamp() - currentSample / frequency;
			chan = new Channel(this, CHANNEL_BUFSIZE);
		}
	}

	public function stop( immediate = false ) {
		if( chan != null ) {
			if( STOP_DELAY == 0 || immediate )
				chan.stop();
			else
				haxe.Timer.delay(chan.stop, STOP_DELAY);
			chan = null;
		}
	}

	public function dispose() {
		stop();
		all.remove(id);
		id = 0;
	}

	public inline function toInt() return id;
	public static inline function ofInt(i) return all.get(i);
}


class Buffer {
	static var ID = 0;
	static var all = new Map<Int,Buffer>();

	public var id : Int;
	public var data : haxe.ds.Vector<F32>;
	public var frequency : Int = 1;
	public var samples : Int = 0;

	public function new() {
		id = ++ID;
		all.set(id, this);
	}

	public function dispose() {
		data = null;
		all.remove(id);
		id = 0;
	}

	public function alloc(size) {
		if( data == null || data.length != size )
			data = new haxe.ds.Vector(size);
		return data;
	}

	public inline function toInt() return id;
	public static inline function ofInt(i) return all.get(i);

}

/**
	On platforms that don't have native support for OpenAL, the Driver uses this
	emulator that only requires a NativeChannel implementation
**/
class Emulator {

	public static var NATIVE_FREQ(get,never) : Int;
	static var CACHED_FREQ : Null<Int>;
	static function get_NATIVE_FREQ() {
		if( CACHED_FREQ == null )
			CACHED_FREQ = #if js Std.int(hxd.snd.webaudio.Context.get().sampleRate) #else 44100 #end;
		return CACHED_FREQ;
	}

	// api

	public static function dopplerFactor(value : F32) {}
	public static function dopplerVelocity(value : F32) {}
	public static function speedOfSound(value : F32) {}
	public static function distanceModel(distanceModel : Int) {}

	// Renderer State management
	public static function enable(capability : Int) {}
	public static function disable(capability : Int) {}
	public static function isEnabled(capability : Int) return false;

	// State retrieval
	public static function getBooleanv(param : Int, values : Bytes) {
		throw "TODO";
	}
	public static function getIntegerv(param : Int, values : Bytes) {
		throw "TODO";
	}
	public static function getFloatv(param : Int, values : Bytes) {
		throw "TODO";
	}
	public static function getDoublev(param : Int, values : Bytes) {
		throw "TODO";
	}

	public static function getString(param : Int) : Bytes {
		throw "TODO";
	}

	public static function getBoolean(param : Int) : Bool {
		throw "TODO";
	}

	public static function getInteger(param : Int) : Int {
		throw "TODO";
	}

	public static function getFloat(param : Int) : F32 {
		throw "TODO";
	}

	public static function getDouble(param : Int) : Float {
		throw "TODO";
	}

	// Error retrieval
	public static function getError() : Int {
		return 0;
	}

	// Extension support
	public static function loadExtensions() {}

	public static function isExtensionPresent(extname : Bytes) : Bool {
		return false;
	}

	public static function getEnumValue(ename : Bytes) : Int {
		throw "TODO";
	}
	//public static function getProcAddress(fname   : Bytes) : Void*;

	// Set Listener parameters
	public static function listenerf(param : Int, value  : F32)
	{
		#if js
		switch (param) {
			case GAIN:
				hxd.snd.webaudio.Context.masterGain.gain.value = value;
		}
		#end
	}
	public static function listener3f(param : Int, value1 : F32, value2 : F32, value3 : F32) {}
	public static function listenerfv(param : Int, values : Bytes) {}
	public static function listeneri(param : Int, value  : Int) {}
	public static function listener3i(param : Int, value1 : Int, value2 : Int, value3 : Int) {}
	public static function listeneriv(param : Int, values : Bytes) {}

	// Get Listener parameters
	public static function getListenerf(param : Int) : F32 {
		throw "TODO";
	}
	public static function getListener3f(param : Int, values : Array<F32> ) {
		throw "TODO";
	}

	public static function getListenerfv(param : Int, values : Bytes) {
		throw "TODO";
	}
	public static function getListeneri(param : Int) : Int {
		throw "TODO";
	}
	public static function getListener3i(param : Int, values : Array<Int> ) {
		throw "TODO";
	}
	public static function getListeneriv(param : Int, values : Bytes) {
		throw "TODO";
	}

	// Source management
	public static function genSources(n : Int, sources : Bytes) {
		for( i in 0...n )
			sources.setInt32(i << 2, new Source().toInt());
	}

	public static function deleteSources(n : Int, sources : Bytes) {
		for( i in 0...n )
			Source.ofInt(sources.getInt32(i << 2)).dispose();
	}

	public static function isSource(source : Source) : Bool {
		return source != null;
	}

	// Set Source parameters
	public static function sourcef(source : Source, param : Int, value : F32) {
		switch( param ) {
		case SEC_OFFSET:
			source.currentSample = source.buffers.length == 0 ? 0 : Std.int(value * source.frequency);
			if( source.playing ) {
				source.stop(true);
				source.play();
			}
		case GAIN:
			source.volume = value;
			#if js
			if (source.chan != null) @:privateAccess source.chan.gain.gain.value = value;
			#end
		case REFERENCE_DISTANCE, ROLLOFF_FACTOR, MAX_DISTANCE:
			// nothing (spatialization)
		case PITCH:
			// nothing
		default:
			throw "Unsupported param 0x" + StringTools.hex(param);
		}
	}
	public static function source3f(source : Source, param : Int, value1 : F32, value2 : F32, value3 : F32) {
		switch( param ) {
		case POSITION, VELOCITY, DIRECTION:
			// nothing
		default:
			throw "Unsupported param 0x" + StringTools.hex(param);
		}
	}
	public static function sourcefv(source : Source, param : Int, values : Bytes) {
		switch( param ) {
		default:
			throw "Unsupported param 0x" + StringTools.hex(param);
		}
	}
	public static function sourcei(source : Source, param : Int, value  : Int) {
		switch( param ) {
		case BUFFER:
			var b = Buffer.ofInt(value);
			source.buffers = b == null ? [] : [b];
			source.updateDuration();
			source.currentSample = 0;
		case LOOPING:
			source.loop = value != 0;
		case SAMPLE_OFFSET:
            source.currentSample = Std.int(getSourcef(source, SEC_OFFSET) / source.frequency);
			if( source.playing ) {
				source.stop(true);
				source.play();
			}
		case SOURCE_RELATIVE:
			// nothing
		case EFX.DIRECT_FILTER:
			// nothing
		default:
			throw "Unsupported param 0x" + StringTools.hex(param);
		}
	}
	public static function source3i(source : Source, param : Int, value1 : Int, value2 : Int, value3 : Int) {
		switch( param ) {
		default:
			throw "Unsupported param 0x" + StringTools.hex(param);
		}
	}
	public static function sourceiv(source : Source, param : Int, values : Bytes) {
		switch( param ) {
		default:
			throw "Unsupported param 0x" + StringTools.hex(param);
		}
	}

	// Get Source parameters