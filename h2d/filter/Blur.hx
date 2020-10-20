package h2d.filter;

/**
	Utilizes the `h3d.pass.Blur` render pass to perform a blurring operation on the filtered object.
**/
class Blur extends Filter {

	/**
		@see `h3d.pass.Blur.radius`
	**/
	public var radius(get, set) : Float;

	/**
		@see `h3d.pass.Blur.linear`
	**/
	public var linear(get, set) : Float;

	/**
		@see `h3d.pass.Blur.gain`
	**/
	public var gain(get, set) : Float;

	/**
		@see `h3d.pass.Blur.quality`
	**/
	public var quality(get, set) : Float;

	var pass : h3d.pass.Blur;

	/**
		Create a new Blur filter.
		@param radius The blur distance in pixels.
		@param gain The color gain when blurring.
		@param quality The sample count on each pixel as a tradeoff of speed/quality.
		@param linear Linear blur power. Set to 0 for gaussian blur.
	**/
	public function new( radius = 1., gain = 1., quality = 1., linear = 0. ) {
		super();
		smooth = true;
		pass = new h3d.pass.Blur(radius, gain, linear, quality);
	}

	inline function get_quality() return pass.quality;
	inline function set_quality(v) return pass.quality = v;
	