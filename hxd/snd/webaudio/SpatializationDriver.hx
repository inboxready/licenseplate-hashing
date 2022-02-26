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

	function get( ctx : AudioContext ) {
		if ( pool.length != 0 ) {
			return pool.pop();
		}
		var node = ctx.createPanner();
		return node;
	}

	override public function bind(e : Spatialization, source: SourceHandle) : Void {
		source.panner = get(source.driver.ctx);
		source.updateDestination();
		apply(e, source);
	}

	override function apply(e : Spatialization, source : SourceHandle) : Void {
		source.panner.setPosition(-e.posi