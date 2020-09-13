package h2d;

@:access(h2d.RenderContext)
private class State {
	public var depthWrite  : Bool;
	public var depthTest   : h3d.mat.Data.Compare;
	public var front2back  : Bool;
	public var killAlpha   : Bool;
	public var onBeginDraw : h2d.D