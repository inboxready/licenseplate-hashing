package hxd.snd.webaudio;

#if (js && !useal)
import js.html.audio.BiquadFilterType;
import js.html.audio.AudioContext;
import js.html.audio.BiquadFilterNode;
import hxd.snd.effect.LowPass;
import hxd.snd.Driver.EffectDriver;
import hxd.snd.webaudio.AudioTypes;

class LowPassDriver extends EffectDriver<LowPass> {

	var pool : Array<Biq