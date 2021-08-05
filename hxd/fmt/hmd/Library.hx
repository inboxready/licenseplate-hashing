
package hxd.fmt.hmd;
import hxd.fmt.hmd.Data;

private class FormatMap {
	public var size : Int;
	public var offset : Int;
	public var def : h3d.Vector;
	public var next : FormatMap;
	public function new(size, offset, def, next) {
		this.size = size;
		this.offset = offset;
		this.def = def;
		this.next = next;
	}
}

class GeometryBuffer {
	public var vertexes : haxe.ds.Vector<hxd.impl.Float32>;
	public var indexes : haxe.ds.Vector<Int>;
	public function new() {
	}
}

class Library {

	public var resource(default,null) : hxd.res.Resource;
	public var header(default,null) : Data;
	var cachedPrimitives : Array<h3d.prim.HMDModel>;
	var cachedAnimations : Map<String, h3d.anim.Animation>;
	var cachedSkin : Map<String, h3d.anim.Skin>;

	public function new(res,  header) {