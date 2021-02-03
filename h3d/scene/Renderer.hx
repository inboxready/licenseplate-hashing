package h3d.scene;

class PassObjects {
	public var name : String;
	public var passes : h3d.pass.PassList;
	public var rendered : Bool;
	public function new() {
		passes = new h3d.pass.PassList();
	}
}

enum RenderMode{
	Default;
	LightProbe;
}

@:allow(hrt.prefab.rfx.RendererFX)
@:allow(h3d.pass.Shadows)
class Renderer extends hxd.impl.AnyProps {

	var defaultPass : h3d.pass.Base;
	var passObjects : Map<String,PassObjects>;
	var allPasses : Array<h3d.pass.Base>;
	var emptyPasses = new h3d.pass.PassList();
	var ctx : RenderContext;
	var hasSetTarget = false;
	var frontToBack : h3d.pass.PassList -> Void;
	var backToFront : h3d.pass.PassList -> Void;
	var debugging = false;

	public var effects : Array<h3d.impl.RendererFX> = [];

	public var renderMode : RenderMode = Default;

	public var shadows : Bool = true;

	public function new() {
		allPasses = [];
		passObjects = new Map();
		props = getDefaultProps();
		// pre allocate closures
		frontToBack = depthSort.bind(true);
		backToFront = depthSort.bind(false);
	}

	public function getEffect<T:h3d.impl.RendererFX>( cl : Class<T> ) : T {
		for( f in effects ) {
			var 