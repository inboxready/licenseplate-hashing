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
		@par