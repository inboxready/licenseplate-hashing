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

		// init properties
		for( m in getAllModels() ) {
			for( p in m.getAll("Properties70.P") )
				switch( p.props[0].toString() ) {
				case "UDP3DSMAX" | "Events":
					var userProps = p.props[4].toString().split("&cr;&lf;");
					for( p in userProps ) {
						var pl = p.split("=");
						var pname = StringTools.trim(pl.shift());
						var pval = StringTools.trim(pl.join("="));
						switch( pname ) {
						case "UV" if( pval != "" ):
							var xml = try Xml.parse(pval) catch( e : Dynamic ) throw "Invalid UV data in " + m.getName();
							var frames = [for( f in new Access(xml.firstElement()).elements ) { var f = f.innerData.split(" ");  { t : Std.parseFloat(f[0]) * 9622116.25, u : Std.parseFloat(f[1]), v : Std.parseFloat(f[2]) }} ];
							if( uvAnims == null ) uvAnims = new Map();
							uvAnims.set(m.getName(), frames);
						case "Events":
							var xml = try Xml.parse(pval) catch( e : Dynamic ) throw "Invalid Events data in " + m.getName();
							animationEvents = [for( f in new Access(xml.firstElement()).elements ) { var f = f.innerData.split(" ");  { frame : Std.parseInt(f.shift()), data : StringTools.trim(f.join(" ")) }} ];
						default:
						}
					}
				default:
				}
		}
	}

	function toFloats( n : FbxNode ) {
		return switch( n.props[0] ) {
		case PInts(vl):
			var vl = [for( v in vl ) (v:Float)];
			n.props[0] = PFloats(vl);
			vl;
		case PFloats(vl):
			vl;
		default:
			throw n.props[0]+" should be floats ";
		}
	}

	function getAllModels() {
		return this.root.getAll("Objects.Model");
	}

	function getRootModels() {
		return [for( m in getAllModels() ) if( isRootModel(m) ) m];
	}

	function isRootModel( m ) {
		return getParent(m,"Model",true) == null;
	}

	function updateModelScale() {
		var unitScale = 1;
		var originScale = 1;
		var upAxis = 1;
		var originalUpAxis = 2;
		for( p in root.getAll("GlobalSettings.Properties70.P") ) {
			switch( p.props[0].toString() ) {
			case "UnitScaleFactor": unitScale = p.props[4].toInt();
			case "OriginalUnitScaleFactor": originScale = p.props[4].toInt();
			case "UpAxis": upAxis = p.props[4].toInt();
			case "OriginalUpAxis": originalUpAxis = p.props[4].toInt();
			default:
			}
		}
		var scaleFactor : Float = unitScale == 100 && originScale == 1 ? 100 : 1;
		var geometryScaleFactor = scaleFactor;

		if( upAxis == 1 ) // Y-up
			convertYupToZup(originalUpAxis);

		var app = "";
		for( p in root.getAll("FBXHeaderExtension.SceneInfo.Properties70.P") )
			switch( p.props[0].toString() ) {
			case "LastSaved|ApplicationName": app = p.props[4].toString();
			default:
			}
		if( app.indexOf("Blender") >= 0 && unitScale == originScale ) {
			if ( unitScale == 0 ) scaleFactor = 1; // 0.9999999776482582 scale turning into 0
			else scaleFactor = unitScale / 100; // Adjust blender output scaling
		}

		if( scaleFactor == 1 && geometryScaleFactor == 1 )
			return;

		// scale on geometry
		if( geometryScaleFactor != 1 ) {
			for( g in this.root.getAll("Objects.Geometry.Vertices") ) {
				var v = toFloats(g);
				for( i in 0...v.length )
					v[i] = v[i] / geometryScaleFactor;
			}
		}

		if( scaleFactor == 1 )
			return;

		// scale on root models
		for( m in getAllModels() ) {
			var isRoot = isRootModel(m);
			for( p in m.getAll("Properties70.P") )
				switch( p.props[0].toString() ) {
				case "Lcl Scaling" if( isRoot ):
					for( idx in [4,5,6] ) {
						var v = p.props[idx].toFloat();
						p.props[idx] = PFloat(v * scaleFactor);
					}
				case "Lcl Translation", "GeometricTranslation" if( !isRoot ):
					for( idx in [4,5,6] ) {
						var v = p.props[idx].toFloat();
						p.props[idx] = PFloat(v / scaleFactor);
					}
				default:
				}
		}
		// scale on skin
		for( t in this.root.getAll("Objects.Deformer.Transform") ) {
			var m = toFloats(t);
			m[12] /= scaleFactor;
			m[13] /= scaleFactor;
			m[14] /= scaleFactor;
		}
		// scale on animation
		for( n in this.root.getAll("Objects.AnimationCurveNode") ) {
			var name = n.getName();
			var model = getParent(n,"Model",true);
			var isRoot = model != null && getParent(model,"Model",true) == null;
			for( p in n.getAll("Properties70.P") )
				switch( p.props[0].toString() ) {
				case "d|X", "d|Y", "d|Z" if( name == "T" && !isRoot ): p.props[4] = PFloat(p.props[4].toFloat() / scaleFactor);
				case "d|X", "d|Y", "d|Z" if( name == "S" && isRoot ): p.props[4] = PFloat(p.props[4].toFloat() * scaleFactor);
				default:
				}
			for( c in getChilds(n,"AnimationCurve") ) {
				var vl = toFloats(c.get("KeyValueFloat"));
				switch( name ) {
				case "T" if( !isRoot ):
					for( i in 0...vl.length )
						vl[i] = vl[i] / scaleFactor;
				case "S" if( isRoot ):
					for( i in 0...vl.length )
						vl[i] = vl[i] * scaleFactor;
				default:
				}
			}
		}
	}

	function convertYupToZup( originalUpAxis : Int ) {
		switch( originalUpAxis ) {
			case 2: // Original Axis Z - Maya & 3DS Max
				for( rootObject in getRootModels() ) {
					var props = rootObject.get("Properties70");
					for( c in props.childs ) {
						if( c.props[0].toString() == "PreRotation" && c.props[4].toFloat() == -90 && c.props[5].toFloat()== 0 && c.props[6].toFloat() == 0 ) {
							props.childs.remove(c);
							break;
						}
					}
				}
			case -1, 1: // Original Axis -Y or Y - Blender & Maya
				for( m in getRootModels() ) {
					var needPreRot = true;
					for( c in root.getAll("GlobalSettings.Properties70.P") ) {
						if( c.props[0].toString() == "PreRotation" && c.props[4].toFloat() == 90 && c.props[5].toFloat()== 0 && c.props[6].toFloat() == 0 ) {
							needPreRot = false;
							break;
						}
					}
					if( needPreRot ) {
						var preRotProp : FbxNode = {name : "P", props : [PString("PreRotation"), PString("Vector3D"), PString("Vector"), PString(""), PFloat(90),PFloat(0),PFloat(0)], childs : []};
						m.get("Properties70").childs.insert(0, preRotProp);
					}
				}
			default:
				throw "From Y-up to Z-up with orginalUpAxis = " + originalUpAxis + " not implemented.";
		}
	}

	function convertPoints( a : Array<Float> ) {
		var p = 0;
		for( i in 0...Std.int(a.length / 3) ) {
			a[p] = -a[p]; // inverse X axis
			p += 3;
		}
	}

	public function leftHandConvert() {
		if( leftHand ) return;
		leftHand = true;
		for( g in root.getAll("Objects.Geometry") ) {
			for( v in g.getAll("Vertices") )
				convertPoints(v.getFloats());
			for( v in g.getAll("LayerElementNormal.Normals") )
				convertPoints(v.getFloats());
			for( v in g.getAll("LayerElementTangent.Tangents") )
				convertPoints(v.getFloats());
			for( v in g.getAll("LayerElementBinormal.Binormals") )
				convertPoints(v.getFloats());
		}
	}

	function init( n : FbxNode ) {
		switch( n.name ) {
		case "Connections":
			for( c in n.childs ) {
				if( c.name != "C" )
					continue;
				var child = c.props[1].toInt();
				var parent = c.props[2].toInt();

				// Maya exports invalid references
				if( ids.get(child) == null || ids.get(parent) == null ) continue;

				var name = c.props[3];

				if( name != null ) {
					var name = name.toString();
					var nc = namedConnect.get(parent);
					if( nc == null ) {
						nc = new Map();
						namedConnect.set(parent, nc);
					}
					nc.set(name, child);
					// don't register as a parent, since the target can also be the child of something else
					if( name == "LookAtProperty" ) continue;
				}

				var c = connect.get(parent);
				if( c == null ) {
					c = [];
					connect.set(parent, c);
				}
				c.push(child);

				if( parent == 0 )
					continue;

				var c = invConnect.get(child);
				if( c == null ) {
					c = [];
					invConnect.set(child, c);
				}
				c.push(parent);
			}
		case "Objects":
			for( c in n.childs )
				ids.set(c.getId(), c);
		default:
		}
	}

	public function getGeometry( name : String = "" ) {
		var geom = null;
		for( g in root.getAll("Objects.Geometry") )
			if( g.hasProp(PString("Geometry::" + name)) ) {
				geom = g;
				break;
			}
		if( geom == null )
			throw "Geometry " + name + " not found";
		return new Geometry(this, geom);
	}

	public function getParent( node : FbxNode, nodeName : String, ?opt : Bool ) {
		var p = getParents(node, nodeName);
		if( p.length > 1 )
			throw node.getName() + " has " + p.length + " " + nodeName + " parents "+[for( o in p ) o.getName()].join(",");
		if( p.length == 0 && !opt )
			throw "Missing " + node.getName() + " " + nodeName + " parent";
		return p[0];
	}

	public function getChild( node : FbxNode, nodeName : String, ?opt : Bool ) {
		var c = getChilds(node, nodeName);
		if( c.length > 1 )
			throw node.getName() + " has " + c.length + " " + nodeName + " childs "+[for( o in c ) o.getName()].join(",");
		if( c.length == 0 && !opt )
			throw "Missing " + node.getName() + " " + nodeName + " child";
		return c[0];
	}

	public function getSpecChild( node : FbxNode, name : String ) {
		var nc = namedConnect.get(node.getId());
		if( nc == null )
			return null;
		var id = nc.get(name);
		if( id == null )
			return null;
		return ids.get(id);
	}

	public function getChilds( node : FbxNode, ?nodeName : String ) {
		var c = connect.get(node.getId());
		var subs = [];
		if( c != null )
			for( id in c ) {
				var n = ids.get(id);
				if( n == null ) throw id + " not found";
				if( nodeName != null && n.name != nodeName ) continue;
				subs.push(n);
			}
		return subs;
	}

	public function getParents( node : FbxNode, ?nodeName : String ) {
		var c = invConnect.get(node.getId());
		var pl = [];
		if( c != null )
			for( id in c ) {
				var n = ids.get(id);
				if( n == null ) throw id + " not found";
				if( nodeName != null && n.name != nodeName ) continue;
				pl.push(n);
			}
		return pl;
	}

	public function getRoot() {
		return root;
	}

	function ignoreMissingObject( id : Int ) {
		var def = defaultModelMatrixes.get(id);
		if( def == null ) {
			def = new DefaultMatrixes();
			def.wasRemoved = -2;
			defaultModelMatrixes.set(id, def);
		}
	}

	function buildHierarchy() {
		// init objects
		var oroot = new TmpObject();
		var objects = new Array<TmpObject>();
		var hobjects = new Map<Int, TmpObject>();

		hobjects.set(0, oroot);
		for( model in getAllModels() ) {
			if( skipObjects.get(model.getName()) )
				continue;
			var mtype = model.getType();
			var isJoint = mtype == "LimbNode" && (!unskinnedJointsAsObjects || !isNullJoint(model));
			var o = new TmpObject();
			o.model = model;
			o.isJoint = isJoint;
			o.isMesh = mtype == "Mesh";
			hobjects.set(model.getId(), o);
			objects.push(o);
		}

		// build hierarchy
		for( o in objects ) {
			var p = getParent(o.model, "Model", true);
			var pid = if( p == null ) 0 else p.getId();
			var op = hobjects.get(pid);
			if( op == null ) op = oroot; // if parent has been removed
			op.childs.push(o);
			o.parent = op;
		}

		inline function getDepth( o : TmpObject ) {
			var k = 0;
			while( o != oroot ) {
				o = o.parent;
				k++;
			}
			return k;
		}

		// look for common skin ancestor
		for( o in objects ) {
			if( !o.isMesh ) continue;
			var g = getChild(o.model, "Geometry");
			var def = getChild(g, "Deformer", true);
			if( def == null ) continue;
			var bones = [for( d in getChilds(def, "Deformer") ) hobjects.get(getChild(d, "Model").getId())];
			if( bones.length == 0 ) continue;


			// first let's go the minimal depth for all bones
			var minDepth = getDepth(bones[0]);
			for( i in 1...bones.length ) {
				var d = getDepth(bones[i]);
				if( d < minDepth ) minDepth = d;
			}
			var out = [];
			for( i in 0...bones.length ) {
				var b = bones[i];
				var n = getDepth(b) - minDepth;
				for( i in 0...n ) {
					b.isJoint = true;
					b = b.parent;
				}
				out.remove(b);
				out.push(b);
			}
			bones = out;

			while( bones.length > 1 ) {
				for( b in bones )
					b.isJoint = true;
				var parents = [];
				for( b in bones ) {
					if( b.parent == oroot || b.parent.isMesh ) continue;
					parents.remove(b.parent);
					parents.push(b.parent);
				}
				bones = parents;
			}
		}

		// propagates joint flags
		var changed = true;
		while( changed ) {
			changed = false;
			for( o in objects ) {
				if( o.isJoint || o.isMesh ) continue;
				if( o.parent.isJoint ) {
					o.isJoint = true;
					changed = true;
					continue;
				}
				var hasJoint = false;
				for( c in o.childs )
					if( c.isJoint ) {
						hasJoint = true;
						break;
					}
				if( hasJoint )
					for( c in o.parent.childs )
						if( c.isJoint ) {
							o.isJoint = true;
							changed = true;
							break;
						}
			}
		}
		return { root : oroot, objects : objects };
	}

	function getObjectCurve( curves : Map < Int, AnimCurve > , model : FbxNode, curveName : String, animName : String ) : AnimCurve {
		var c = curves.get(model.getId());
		if( c != null )
			return c;
		var name = model.getName();
		if( skipObjects.get(name) )
			return null;
		var def = getDefaultMatrixes(model);
		if( def == null )
			return null;
		// if it's a move animation on a terminal unskinned joint, let's skip it
		var isMove = curveName != "Visibility" && curveName != "UV";
		if( def.wasRemoved != null && (isMove || def.wasRemoved == -1) )
			return null;
		// allow not move animations on root model
		if( def.wasRemoved != null && def.wasRemoved != -2 ) {
			// apply it on the skin instead
			model = ids.get(def.wasRemoved);
			name = model.getName();
			c = curves.get(def.wasRemoved);
			def = getDefaultMatrixes(model);
			// todo : change behavior not to remove the mesh but the skin instead!
			if( def == null ) throw "assert";
		}
		if( c == null ) {
			c = new AnimCurve(def, name);
			curves.set(model.getId(), c);
		}
		return c;
	}


	public function mergeModels( modelNames : Array<String> ) {
		if( modelNames.length <= 1 )
			return;
		var models = getAllModels();
		function getModel(name) {
			for( m in models )
				if( m.getName() == name )
					return m;
			throw "Model not found " + name;
			return null;
		}
		var m = getModel(modelNames[0]);
		var geom = new Geometry(this, getChild(m, "Geometry"));
		var def = getChild(geom.getRoot(), "Deformer", true);
		var subDefs = getChilds(def, "Deformer");
		for( i in 1...modelNames.length ) {
			var name = modelNames[i];
			var m2 = getModel(name);
			var geom2 = new Geometry(this, getChild(m2, "Geometry"));
			var vcount = Std.int(geom.getVertices().length / 3);

			skipObjects.set(name, true);

			// merge materials
			var mindex = [];
			var materials = getChilds(m, "Material");
			for( mat 