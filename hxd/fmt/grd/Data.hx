package hxd.fmt.grd;

class Gradient {
	public var name              : String;
	public var interpolation     : Float;
	public var colorStops        : Array<ColorStop>;
	public var transparencyStops : Array<TransparencyStop>;
	public var gradientStops     : Array<GradientStop>;

	public function new() {
		colorStops = [];
		transparencyStops = [];
		gradientStops = [];
	}
}

class ColorStop {
	public var color    : Color;
	public var location : Int;
	public var midp