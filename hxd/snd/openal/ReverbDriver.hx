package hxd.snd.openal;

import hxd.snd.openal.AudioTypes;
import hxd.snd.effect.*;

@:access(hxd.snd.effect.LowPass)
@:access(hxd.snd.openal.LowPassDriver)
class ReverbDriver extends hxd.snd.Driver.EffectDriver<Reverb> {
	var driver    : Driver;
	var inst      : openal.EFX.Effect;
	var slot      : openal.EFX.EffectSlot;
	var dryFilter : LowPass;
	var dryGain   : Float;

	public function new(driver) {
		super();
		this.driver = driver;
		this.dryFilter = new LowPass();
	}

	override function acquire() : Void {
		// create effect
		var bytes = driver.getTmpBytes(4);
		EFX.genEffects(1, bytes);
		inst = openal.EFX.Effect.ofInt(bytes.getInt32(0));
		if (AL.getError() != AL.NO_ERROR) throw "could not create an ALEffect instance";
		EFX.effecti(inst, EFX.EFFECT_TYPE, EFX.EFFECT_REVERB);

		// create effect slot
		var bytes =