package hxd.snd.effect;

// I3DL reverb

class Reverb extends hxd.snd.Effect {
	public var wetDryMix         : Float; // [0.0, 100.0] %
	public var room              : Float; // [-10000 0] mb
	public var roomHF            : Float; // [-10000, 0] mb
	public var roomRolloffFactor : Float; // [0.0, 10.0]
	public var decayTime         : Float; // [0.1, 20.0] s
	public var decayHFRatio      : Float; // [0.1, 2.0]
	public var reflections       : Float; // [-10000, 1000] mb
	public var reflectionsDelay  : Float; // [0.0, 0.3] s
	public var reverb            : Float; // [-10000, 2000] mb
	public var reverbDelay       : Float; // [0.0, 0.1] s
	public var diffusion         : Float; // [0.0, 100.0] %
	public var density           : Float; // [0.0, 100.0] %
	public var hfReference       : Float; // [20.0, 20000.0]

	pub