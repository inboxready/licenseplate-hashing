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
	var dryGain   : Float