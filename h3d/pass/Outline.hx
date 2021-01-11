package h3d.pass;

@ignore("shader")
class Outline extends ScreenFx<h3d.shader.Outline2D> {
	public var size : Float;
	public var color : Int;
	public var alpha : Float = 1.;
	public var quality : Float;
	public var multiplyAlpha : Bool;

	public function new(size = 4.0, color = 0x000000, quality = 0.3, multiplyAlpha = true) {
		super(new h3d.shader.Outline2D());
		this.size = size;
		this.color = color;
		this.quality = quality;
		this.multiplyAlpha = mult