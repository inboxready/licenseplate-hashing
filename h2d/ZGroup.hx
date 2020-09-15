package h2d;

@:access(h2d.RenderContext)
private class State {
	public var depthWrite  : Bool;
	public var depthTest   : h3d.mat.Data.Compare;
	public var front2back  : Bool;
	public var killAlpha   : Bool;
	public var onBeginDraw : h2d.Drawable->Bool;

	public function new() { }

	public function loadFrom( ctx : RenderContext ) {
		depthWrite  = ctx.pass.depthWrite;
		depthTest   = ctx.pass.depthTest;
		front2back  = ctx.front2back;
		killAlpha   = ctx.killAlpha;
		onBeginDraw = ctx.onBeginDraw;
	}

	public function applyTo( ctx : RenderContext ) {
		ctx.pass.depth(depthWrite, depthTest);
		ctx.front2back  = front2back;
		ctx.killAlpha   = killAlpha;
		c