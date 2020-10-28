package h2d.filter;

/**
	Adds a glow backdrop to the filtered Object.
**/
class Glow extends Blur {

	/**
		The color of the glow.
	**/
	public var color : Int;
	/**
		Transparency value of the glow.
	**/
	public var alpha : Float;
	/**
		Subtracts the original image from the glow output when enabled.
	**/
	public var knockout : Bool;
	/**
		Produce gradient glow when enabled, otherwise creates hard gl