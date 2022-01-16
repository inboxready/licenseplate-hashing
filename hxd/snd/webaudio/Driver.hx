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
		return Context.getBuffer(channels, sampleCount,