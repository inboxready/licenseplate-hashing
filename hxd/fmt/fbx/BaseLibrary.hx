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

	public static inline function rightHandToLeft( m : h3d.Matrix ) {
		// if [x,y,z] is our original point and M the matrix
		// in right hand we have [x,y,z] * M = [x',y',z']
		// we need to ensure that left hand matrix convey the x axis flip,
		// in order to have [-x,y,z] * M = [-x',y',z']
		m._12 = -m._12;
		m._13 = -m._13;
		m._21 = -m._21;
		m._31 = -m._31;
		m._41 = -m._41;
	}

	public function toMatrix(leftHand) {
		var m = new h3d.Matrix();
		m.identity();
		if( scale != null ) m.scale(scale.x, scale.y, scale.z);
		if( rotate != null ) m.rotate(rotate.x, rotate.y, rotate.z);
		if( preRot != null ) m.rotate(preRot.x, preRot.y, preRot.z);
		if( trans != null ) m.translate(trans.x, trans.y, trans.z);
		if( leftHand ) rightHandToLeft(m);
		return m;
	}

	public function toQuaternion(leftHand) {
		var m = new h3d.Matrix();
		m.identity();
		if( rotate != null ) m.rotate(rotate.x, rotate.y, rotate.z);
		if( preRot != null ) m.rotate(preRot.x, preRot.y, preRot.z);
		if( leftHand ) rightHandToLeft(m);
		var q = new h3d.Quat();
		q.initRotateMatrix(m);
		return q;
	}

}

class BaseLibrary {

	var root : FbxNode;
	var ids : Map<Int,FbxNode>;
	var connect : Map<Int,Array<Int>>;
	var namedConnect : Map<Int,Map<String,Int>>;
	var invConnect : Map<Int,Array<Int>>;
	var leftHand : Bool;
	var defaultModelMatrixes : Map<Int,DefaultMatrixes>;
	var uvAnims : Map<String, Array<{ t : Float, u : Float, v : Float }>>;
	var animationEvents : Array<{ frame : Int, data : String }>;
	var isMaya : Bool;

	public var fileName : String;

	/**
		The FBX version that was decoded
	**/
	public var version : Float = 0.;

	/**
		Allows to prevent some terminal unskinned joints to be removed, for instance if we want to track their position
	**/
	public var keepJoints : Map<String,Bool>;

	/**
		Allows to skip some objects from being processed as if they were not part of the FBX
	**/
	public var skipObjects : Map<String,Bool>;

	/**
		Use 4 bones of influence per vertex instead of 3
	**/
	public var fourBonesByVertex = false;

	/**
		If there are too many bones, the model will be split in separate render passes.
	**/
	public var maxBonesPerSkin = 34;

	/**
		Consider unskinned joints to be simple objects
	**/
	public var unskinnedJointsAsObjects : Bool;

	public var allowVertexColor : Bool = true;

	/**
		Convert centimeters to meters and axis to Z-up (Maya FBX export)
	**/
	public var normalizeScaleOrient : Bool = true;

	/**
		Keep high precision values. Might increase animation data size and compressed size.
	**/
	public var highPrecision : Bool = false;

	public function new( fileName ) {
		this.fileName = fileName;
		root = { name : "Root", props : [], childs : [] };
		keepJoints = new Map();
		skipObjects = new Map();
		reset();
	}

	function reset() {
		ids = new Map();
		connect = new Map();
		namedConnect = new Map();
		invConnect = new Map();
		defaultModelMatrixes = new Map();
	}

	public function loadFile( data : Bytes ) {
		load(Parser.parse(data));
	}

	public function load( root : FbxNode ) {
		reset();
		this.root = root;

		version = root.get("FBXHeaderExtension.FBXVersion").props[0].toInt() / 1000;
		if( Std.int(version) != 7 )
			throw "FBX Version 7.x required : use FBX 2010 export";

		for( p in root.getAll("FBXHeaderExtension.SceneInfo.Properties70.P") )
			if( p.props[0].toString() == "Original|ApplicationName" ) {
				isMaya = p.props[4].toString().toLowerCase().indexOf("maya") >= 0;
				break;
			}

		for( c in root.childs )
			init(c);

		if( normalizeScaleOrient )
			updateModelScale();

		// in