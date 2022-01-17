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

	public function createSource () : Sourc