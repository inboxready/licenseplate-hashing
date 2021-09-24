package hxd.snd;

class LoadingData extends Data {

	var snd : hxd.res.Sound;
	var waitCount = 0;

	public function new(snd) {
		this.snd = snd;
	}

	override function decode(out:ha