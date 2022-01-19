package hxd.snd.webaudio;
#if (js && !useal)

import hxd.snd.webaudio.AudioTypes;
import hxd.snd.Driver.DriverFeature;
import js.html.audio.*;

class Driver implements hxd.snd.Driver {

	public var ctx : AudioContext;
	public var masterGain(get, never) : GainNode;
	public var destination(get, set) : AudioNode;

	var playbackPool : Array<BufferPlayback>;

	public function new()
	{
		playbackPool = [];

		ctx = Context.get();
	}

	/**
		Returns free AudioBuffer instance corresponding to sample count, amount of channels and sample-rate.
	**/
	public inline function getBuffer(channels : Int, sampleCount : Int, rate : Int) : AudioBuffer {
		return Context.getBuffer(channels, sampleCount, rate);
	}

	/**
		Puts AudioBuufer back to it's pool.
	**/
	public inline function putBuffer( buf : AudioBuffer ) {
		Context.putBuffer(buf);
	}

	/**
		Returns free Gain node
	**/
	public inline function getGain():GainNode
	{
		return Context.getGain();
	}

	public inline function putGain(gain:GainNode) {
		Context.putGain(gain);
	}

	public function hasFeature (d : DriverFeature) : Bool {
		switch (d) {
			case MasterVolume: return true;
		}
	}

	public function setMasterVolume (value : Float) : Void {
		masterGain.gain.value = value;
	}

	public function setListenerParams (position : h3d.Vector, direction : h3d.Vector, up : h3d.Vector, ?velocity : h3d.Vector) : Void {
		ctx.listener.setPosition(-position.x, position.y, position.z);
		ctx.listener.setOrientation(-direction.x, direction.y, direction.z, -up.x, up.y, up.z);
		// TODO: Velocity
	}

	public function createSource () : SourceHandle {
		var s = new SourceHandle();
		s.driver = this;
		s.gain = getGain();
		s.updateDestination();
		return s;
	}

	public function playSource (source : SourceHandle) : Void {
		if ( !source.playing ) {
			source.playing = true;
			if ( source.buffers.length != 0 ) {
				var time = ctx.currentTime;
				for ( b in source.buffers ) {
					if ( b.consumed ) continue;
					time = b.start(ctx, source, time);
				}
			}
		}
	}

	public function stopSource (source : SourceHandle) : Void {
		source.playing = false;
		source.sampleOffset = 0;
	}

	public function setSourceVolume (source : SourceHandle, value : Float) : Void {
		source.gain.gain.value = value;
	}

	public function destroySource (source : SourceHandle) : Void {
		stopSource(source);
		source.gain.disconnect();
		source.driver = null;
		putGain(source.gain);
		source.gain = null;
		for ( b in source.buffers ) {
			b.stop();
			b.clear();
			playbackPool.push(b);
		}
		source.buffers = [];
	}

	public function createBuffer () : BufferHandle {
		var b = new BufferHandle();
		b.samples = 0;
		return b;
	}

	public function setBufferData (buffer : BufferHandle, data : haxe.io.Bytes, size : Int, format : Data.SampleFormat, channelCount : Int, samplingRate : Int) : Void {
		var sampleCount = Std.int(size / hxd.snd.Data.formatBytes(format) / channelCount);
		buffer.samples = sampleCount;
		if (sampleCount == 0) return;

		if ( buffer.inst == null ) {
			buffer.inst = getBuffer(channelCount, sampleCount, samplingRate);
		} else if ( buffer.inst.sampleRate != samplingRate || buffer.inst.numberOfChannels != channelCount || buffer.inst.length != sampleCount ) {
			putBuffer(buffer.inst);
			buffer.inst = getBuffer(channelCount, sampleCount, samplingRate);
		}
		switch (format)
		{
			case UI8:
				var ui8 = new hxd.impl.TypedArray.Uint8Array(data.getData());
				if (channelCount == 1) {
					var chn = buffer.inst.getChannelData(0);
					for ( i in 0...sampleCount ) {
						chn[i] = (ui8[i] - 0x80) / 0x80;
					}
				} else {
					var left = buffer.inst.getChannelData(0);
					var right = buffer.inst.getChannelData(1);
					// TODO: 3+ channels
					var r = 0;
					for ( i in 0...sampleCount ) {
						left[i] = (ui8[r] - 0x80) / 0x80;
						right[i] = (ui8[r+1] - 0x80) / 0x80;
						r += channelCount;
					}
				}
			case I16:
				var i16 = new hxd.impl.TypedArray.Int16Array(data.getData());
				if (channelCount == 1) {
					var chn = buffer.inst.getChannelData(0);
					for ( i in 0...sampleCount ) {
						chn[i] = i16[i] / 0x8000;
					}
				} else {
					var left = buffer.inst.getChannelData(0);
					var right = buffer.inst.getChannelData(1);
					// TODO: 3+ channels
					var r = 0;
					for ( i in 0...sampleCount ) {
						left[i] = i16[r] / 0x8000;
						right[i] = i16[r+1] / 0x8000;
						r += channelCount;
					}
				}
			case F32:
				var f32 = new hxd.impl.TypedArray.Float32Array(data.getData());
				if (channelCount == 1) {
					var chn = buffer.inst.getChannelData(0);
					for ( i in 0...sampleCount ) {
						chn[i] = f32[i];
					}
				} else {
					var left = buffer.inst.getChannelData(0