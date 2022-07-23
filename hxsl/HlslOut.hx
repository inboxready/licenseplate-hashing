package hxsl;
using hxsl.Ast;

class Samplers {

	public var count : Int;
	var named : Map<String, Int>;

	public function new() {
		count = 0;
		named = new Map();
	}

	public function make( v : TVar, arr : Array<Int> ) : Array<Int> {

		var ntex = switch( v.type ) {
		case TArray(t, SConst(k)) if( t.isSampler() ): k;
		case t if( t.isSampler() ): 1;
		default:
			return null;
		}

		var names = null;
		if( v.qualifiers != null ) {
			for( q in v.qualifiers ) {
				switch( q ) {
				case Sampler(nl): names = nl.split(",");
				default:
				}
			}
		}
		for( i in 0...ntex ) {
			if( names == null || names[i] == "" )
				arr.push(count++);
			else {
				var idx = named.get(names[i]);
				if( idx == null ) {
					idx = count++;
					named.set(names[i], idx);
				}
				arr.push(idx);
			}
		}
		return arr;
	}

}

class HlslOut {

	static var KWD_LIST = [
		"s_input", "s_output", "_in", "_out", "in", "out", "mul", "matrix", "vector", "export", "half", "float", "double", "line", "linear", "point", "precise",
		"sample" // pssl
	];
	static var KWDS = [for( k in KWD_LIST ) k => true];
	static var GLOBALS = {
		var m = new Map();
		for( g in hxsl.Ast.TGlobal.createAll() ) {
			var n = "" + g;
			n = n.charAt(0).toLowerCase() + n.substr(1);
			m.set(g, n);
		}
		m.set(ToInt, "(int)");
		m.set(ToFloat, "(float)");
		m.set(ToBool, "(bool)");
		m.set(Vec2, "float2");
		m.set(Vec3, "float3");
		m.set(Vec4, "float4");
		m.set(LReflect, "reflect");
		m.set(Fract, "frac");
		m.set(Mix, "lerp");
		m.set(Inversesqrt, "rsqrt");
		m.set(VertexID,"_in.vertexID");
		m.set(InstanceID,"_in.instanceID");
		m.set(IVec2, "int2");
		m.set(IVec3, "int3");
		m.set(IVec4, "int3");
		m.set(BVec2, "bool2");
		m.set(BVec3, "bool3");
		m.set(BVec4, "bool4");
		m.set(FragCoord,"_in.__pos__");
		m.set(FrontFacing, "_in.isFrontFace");
		for( g in m )
			KWDS.set(g, true);
		m;
	};

	var SV_POSITION = "SV_POSITION";
	var SV_TARGET = "SV_TARGET";
	var SV_VertexID = "SV_VertexID";
	var SV_InstanceID = "SV_InstanceID";
	var SV_IsFrontFace = "SV_IsFrontFace";
	var STATIC = "static ";
	var buf : StringBuf;
	var exprIds = 0;
	var exprValues : Array<String>;
	var locals : Map<Int,TVar>;
	var decls : Array<String>;
	var isVertex : Bool;
	var allNames : Map<String, Int>;
	var samplers : Map<Int, Array<Int>>;
	public var varNames : Map<Int,String>;
	public var baseRegister : Int = 0;

	var varAccess : Map<Int,String>;

	public function new() {
		varNames = new Map();
		allNames = new Map();
	}

	inline function add( v : Dynamic ) {
		buf.add(v);
	}

	inline function ident( v : TVar ) {
		add(varName(v));
	}

	function decl( s : String ) {
		for( d in decls )
			if( d == s ) return;
		if( s.charCodeAt(0) == '#'.code )
			decls.unshift(s);
		else
			decls.push(s);
	}

	function addType( t : Type ) {
		switch( t ) {
		case TVoid:
			add("void");
		case TInt:
			add("int");
		case TBytes(n):
			add("uint"+n);
		case TBool:
			add("bool");
		case TFloat:
			add("float");
		case TString:
			add("string");
		case TVec(size, k):
			switch( k ) {
			case VFloat: add("float");
			case VInt: add("int");
			case VBool: add("bool");
			}
			add(size);
		case TMat2:
			add("float2x2");
		case TMat3:
			add("float3x3");
		case TMat4:
			add("float4x4");
		case TMat3x4:
			add("float4x3");
		case TSampler2D:
			add("Texture2D");
		case TSamplerCube:
			add("TextureCube");
		case TSampler2DArray:
			add("Texture2DArray")