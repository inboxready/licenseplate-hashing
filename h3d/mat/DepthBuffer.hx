package h3d.mat;

enum DepthFormat {
	Depth16;
	Depth24;
	Depth24Stencil8;
}

/**
	Depth buffer are used to store per pixel depth information when rendering a scene (also called Z-buffer)
**/
class DepthBuffer {

	@:allow(h3d.impl.MemoryManager)
	var b : h3d.impl.Driver.DepthBuffer;
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var format(default, null) : DepthFormat;

	/**
		Creates a new d