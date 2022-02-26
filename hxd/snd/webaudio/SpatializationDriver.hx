package hxd.snd.webaudio;

#if (js && !useal)
import js.html.audio.PannerNode;
import js.html.audio.AudioContext;
import hxd.snd.effect.Spatialization;
import hxd.snd.Driver.EffectDriver;
import hxd.snd.webaudio.AudioTypes;

class SpatializationDriver extends EffectDriver<Spatialization> {

	var pool : Array<PannerNode>;

	public function new() {
		pool = [];
		super();
	}

	function