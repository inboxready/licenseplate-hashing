
package hxd.snd.webaudio;
#if (js && !useal)
import js.html.audio.*;

class BufferHandle {
	public var inst : AudioBuffer;
	public var isEnd : Bool;
	public var samples : Int;
	public function new() { }
}

@:allow(hxd.snd.webaudio.Driver)
class SourceHandle {
	public var sampleOffset   : Int;
	public var playing        : Bool;

	public var driver : Driver;
	public var lowPass : BiquadFilterNode;
	public var panner : PannerNode;
	public var gain : GainNode;
	public var destination : AudioNode;
	public var buffers : Array<BufferPlayback>;
	public var pitch : Float;
	public var firstPlay : Bool;

	public function new() {
		buffers = [];
		sampleOffset = 0;
		pitch = 1;
		firstPlay = true;
	}

	public function updateDestination() {
		destination = gain;
		if ( lowPass != null ) {
			lowPass.connect(destination);
			destination = lowPass;
		}
		if ( panner != null ) {
			panner.connect(destination);
			destination = panner;
		}
		gain.connect(driver.destination);
		for (b in buffers) {
			if ( b.node != null ) {
				b.restart(this);
			}
		}
	}

	public function applyPitch() {
		// BUG: Because pitch is k-rate parameter, it applies it once per 128 sample block, which throws timings off and creates audio skips.
		// Noticeable mainly with low pitch values, so it's not particularly usable to reduce pitch gradually.
		var t = 0.;
		for ( b in buffers ) {
			t = b.readjust(t, this);
		}
	}
}

class BufferPlayback {

	public var buffer : BufferHandle;
	public var node : AudioBufferSourceNode;
	public var offset : Float; // Buffer offset. Modified when applying effects.
	public var dirty : Bool; // Playback was started - node no longer usable.
	public var consumed : Bool; // Node was played completely (ended event fired)
	public var starts : Float;
	public var ends : Float;

	public var currentSample(get, never):Int;

	static inline var FADE_SAMPLES = 10; // Click prevent at the start.

	var lastSamples:Int;
	var lastTime:Float;

	public function new()
	{

	}

	function get_currentSample ( ):Int {
		if ( consumed ) return buffer.samples;
		if ( node == null || !dirty || node.context.currentTime < lastTime ) return 0;
		lastSamples += Math.floor((node.context.currentTime - lastTime) * buffer.inst.sampleRate * node.playbackRate.value);
		lastTime = node.context.currentTime;
		return lastSamples;
	}

	public function set(buf : BufferHandle, grainOffset : Float) {
		buffer = buf;
		offset = Math.isNaN(grainOffset) ? 0 : grainOffset;
		dirty = false;
		consumed = false;
		starts = 0;
		ends = 0;
	}

	public function start( ctx : AudioContext, source : SourceHandle, time : Float) {
		dirty = true;
		consumed = false;
		if (node != null) {
			stop();
		}
		if ( source.firstPlay && buffer.samples > FADE_SAMPLES ) {
			source.firstPlay = false;
			var channels = [for (i in 0...buffer.inst.numberOfChannels) buffer.inst.getChannelData(i)];
			var j = 0, fade = 0.;
			while ( j < FADE_SAMPLES ) {
				var i = 0;
				while ( i < channels.length ) {
					channels[i][j] *= fade;
					i++;