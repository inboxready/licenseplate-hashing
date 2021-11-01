package hxd.snd.effect;

// I3DL reverb

class Reverb extends hxd.snd.Effect {
	public var wetDryMix         : Float; // [0.0, 100.0] %
	public var room              : Float; // [-10000 0] mb
	public var roomHF            : Float; // [-10000, 0] mb
	public var roomRolloffFactor : Float; // [0.0, 10.0]
	public var decayTime         : Float; // [0.1, 20.0] s
	public var decayHFR