package hxd.snd.webaudio;

#if (js && !useal)
import js.html.audio.BiquadFilterType;
import js.html.audio.AudioContext;
import js.html.audio.BiquadFilterNode;
import hxd.snd.effect.LowPass;
import hxd.snd.Driver.EffectDriver;
import hxd.snd.webaudio.AudioTypes;

class LowPassDriver extends EffectDriver<LowPass> {

	var pool : Array<BiquadFilterNode>;

	public function new() {
		pool = [];
		super();
	}

	function get( ctx : AudioContext ) {
		if ( pool.length != 0 ) {
			return pool.pop();
		}
		var node = ctx.createBiquadFilter();
		node.type = BiquadFilterType.LOWPASS;
		return node;
	}

	override public function bind(e:LowPass, source: SourceHandle) : Void {
		source.lowPass = get(source.driver.ctx);
		source.updateDestination();
		apply(e, source);
	}

	overr