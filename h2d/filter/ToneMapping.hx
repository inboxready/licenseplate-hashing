package h2d.filter;

/**
	Applies a color correction that emulates tonemapping.
**/
class ToneMapping extends Filter {

	/**
		The value used to apply gamma correction.
	**/
	public var gamma(get, set) : Float;

	var pass : h3d.pass.ScreenFx<h3d.shader.pbr.ToneMapping>;
	var shader : h3d.shader.pbr.ToneMapping;

	/**
		Create a new ColorMatrix filter.

		@param gamma The value used to modify the resulting colors.
	**/
	public function new( ?g : Float ) {
		super();
		shader = new h3d.shader.pbr.ToneMapping();
		gamma = g;
		pass = new h3d.pass.ScreenFx(shader);
	}

	inline function get_gamma() return shader.gamma;
	inline function set_gamma(v) return shad