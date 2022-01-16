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
		var bytes = driver.getTmpBytes(4);
		EFX.genAuxiliaryEffectSlots(1, bytes);
		slot = openal.EFX.EffectSlot.ofInt(bytes.getInt32(0));
		if (AL.getError() != AL.NO_ERROR) throw "could not create an ALEffectSlot instance";

		dryFilter.driver.acquire();
		dryFilter.gainHF = 1.0;
	}

	override function release() : Void {
		EFX.auxiliaryEffectSloti(slot, EFX.EFFECTSLOT_EFFECT, EFX.EFFECTSLOT_NULL);

		var bytes = driver.getTmpBytes(4);
		bytes.setInt32(0, slot.toInt());
		EFX.deleteAuxiliaryEffectSlots(1, bytes);

		var bytes = driver.getTmpBytes(4);
		bytes.setInt32(0, inst.toInt());
		EFX.deleteEffects(1, bytes);

		dryFilter.driver.release();
	}

	override function update(e : Reverb) : Void {
		// millibels to gain
		inline function mbToNp(mb : Float) { return Math.pow(10, mb / 100 / 20); }

		EFX.effectf(inst, EFX.REVERB_GAIN,                mbToNp(e.room));
		EFX.effe