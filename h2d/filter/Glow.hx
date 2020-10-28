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
		Produce gradient glow when enabled, otherwise creates hard glow without smoothing.
	**/
	public var smoothColor : Bool;

	/**
		Create new Glow filter.
		@param color The color of the glow.
		@param alpha Transparency value of the glow.
		@param radius The glow distance in pixels.
		@param gain The glow color intensity.
		@param quality The sample count on each pixel as a tradeoff of speed/quality.
		@param smoothColor Produce gradient glow when enabled, otherwise creates hard glow without sm