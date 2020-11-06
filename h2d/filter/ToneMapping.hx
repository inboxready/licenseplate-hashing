package h2d.filter;

/**
	Applies a color correction that emulates tonemapping.
**/
class ToneMapping extends Filter {

	/**
		The value used to apply gamma correction.
	**/
	public var gamma(get, set) : Float;

	var pass : h3d.p