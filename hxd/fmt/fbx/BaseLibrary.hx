package hxd.fmt.fbx;
import haxe.io.Bytes;
using hxd.fmt.fbx.Data;
import h3d.col.Point;

#if (haxe_ver < 4)
import haxe.xml.Fast in Access;
#else
import haxe.xml.Access;
#end

class TmpObject {
	public var index : Int;
	public var model : FbxNode;
	public var parent : TmpObject;
	public var isJoint : Bool;
	public var isMesh : Bool;
	public var childs : Array<TmpObject>;
	#if !(dataOnly || macro)
	public var obj : h3d.scene.Object;
	#end
	public var joint : h3d.anim.Skin.Joint;
	public var skin : TmpObject;
	public function new() {
		childs = [];
	}
}

private class AnimCurve {
	public var def : DefaultMatrixes;
	public var object : String;
	public var t : { t : Array<Float>, x : Array<Float>, y : Array<Float>, z : Array<Float> };
	public var r : { t : Array<Float>, x : Array<Float>, y : Array<Float>, z : Array<Float> };
	public var s : { t : Array<Float>, x : Array<Float>, y : Array<Float>, z : Array<Float> };
	public var a : { t : Array<Float>, v : Array<Float> };
	public var fov : { t : Array<Float>, v : Array<Float> };
	public var roll : { t : Array<Float>, v : Array<Float> };
	public var uv : Array<{ t : Float, u : Float, v : Float }>;
	public function new(def, object) {
		this.def = def;
		this.object = object;
	}
}

class DefaultMatrixes {
	public var trans : Null<Point>;
	public var scale : Null<Point>;
	public var rotate : Null<Point>;
	public var preRot : Null<Point>;
	public var wasRemoved : Null<Int>;

	public var transPos : h3d.Matrix;

	public function new() {
	}

	public static inline function rightHandToLeft( m : h3d.Mat