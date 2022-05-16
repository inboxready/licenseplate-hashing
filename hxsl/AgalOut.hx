package hxsl;

import hxsl.Ast;
import hxsl.RuntimeShader;
import format.agal.Data;

class AgalOut {

	static var COMPS = [X, Y, Z, W];

	var code : Array<Opcode>;
	var current : RuntimeShaderData;
	var version : Int;
	var opcodes : Array<Opcode>;
	var varMap : Map<Int, Reg>;
	var tmpCount : Int;
	var nullReg : Reg;
	var unused : Map<Int, Reg>;

	public function new() {
	}

	public dynamic function error( msg : String, p : Position ) {
		throw msg;
	}

	public function compile( s : RuntimeShaderData, version ) : Data {
		current = s;
		nullReg = new Reg(RTemp, -1, null);
		this.version = version;
		opcodes = [];
		tmpCount = 0;
		varMap = new Map();
		unused = new Map();

		var varying = [];
		var paramCount = 0, inputCount = 0, outCount = 0, texCount = 0;
		for( v in s.data.vars ) {
			var r : Reg;
			switch( v.kind ) {
			case Param, Global:
				switch( v.type ) {
				case TArray(TSampler2D | TSamplerCube, SConst(n)):
					r = new Reg(RTexture, texCount, null);
					texCount += n;
				default:
					r = new Reg(RConst, paramCount, defSwiz(v.type));
					paramCount += regSize(v.type);
				}
			case Var:
				r = new Reg(RVar, v.id, defSwiz(v.type));
				varying.push(r);
			case Output:
				r = new Reg(ROut, outCount, defSwiz(v.type));
				outCount += regSize(v.type);
			case Input:
				r = new Reg(RAttr, inputCount, defSwiz(v.type));
				inputCount += regSize(v.type);
			case Local, Function:
				continue;
			}
			varMap.set(v.id, r);
			unused.set(v.id, r);
		}
		if( paramCount != s.globalsSize + s.paramsSize )
			throw "assert";

		// optimize varying
		// make sure the order is the same in both fragment and vertex shader
		varying.sort(function(r1, r2) return ((r2.swiz == null ? 4 : r2.swiz.length) - (r1.swiz == null ? 4 : r1.swiz.length)) * 100000 + (r1.index - r2.index));
		var valloc : Array<Array<C>> = [];
		for( r in varying ) {
			var size = r.swiz == null ? 4 : r.swiz.length;
			var found = -1;
			for( i in 0...valloc.length ) {
				var v = valloc[i];
				if( v.length < size ) continue;
				found = i;
				break;
			}
			if( found < 0 ) {
				found = valloc.length;
				valloc.push([X, Y, Z, W]);
			}
			r.index = found;
			var v = valloc[found];
			if( size == 4 )
				valloc[found] = [];
			else if( size == 1 )
				r.swiz[0] = v.pop();
			else {
				for( i in 0...size )
					r.swiz[i] = v.shift();
			}
		}

		if( s.data.funs.length != 1 ) throw "assert";
		expr(s.data.funs[0].expr);

		// force write of missing varying components
		for( vid in 0...valloc.length ) {
			var v = valloc[vid];
			if( v.length == 0 ) continue;
			for( i in 0...opcodes.length )
				switch( opcodes[i] ) {
				case OMov(dst, val) if( dst.index == vid && dst.t == RVar ):
					var dst = dst.clone();
					var val = val.clone();
					var last = X;
					val.swiz = [for( i in 0...4 ) { var k = dst.swiz.indexOf(COMPS[i]); if( k >= 0 ) last = val.swiz[k]; last; } ];
					dst.swiz = null;
					opcodes[i] = OMov(dst, val);
					break;
				default:
				}
		}

		// force write of unused inputs
		for( r in unused )
			switch( r.t ) {
			case RAttr:
				var t = allocReg();
				t.swiz = r.swiz == null ? null : [for( i in 0...r.swiz.length ) COMPS[i]];
				op(OMov(t, r));
			default:
			}

		return {
			fragmentShader : !current.vertex,
			version : version,
			code : opcodes,
		};
	}

	function mov(dst, src, t) {
		var n = regSize(t);
		op(OMov(dst, src));
		if( n > 1 )
			for( i in 1...n )
				op(OMov(offset(dst, i), offset(src, i)));
	}

	inline function op(o) {
		opcodes.push(o);
	}

	inline function swiz( r : Reg, sw : Array<C> ) : Reg {
		if( r.access != null ) throw "assert";
		var sw = sw;
		if( r.swiz != null )
			sw = [for( c in sw ) r.swiz[c.getIndex()]];
		return new Reg(r.t, r.index, sw);
	}

	inline function offset( r : Reg, k : Int ) : Reg {
		if( r.access != null ) throw "assert";
		return new Reg(r.t, r.index + k, r.swiz == null ? null : r.swiz.copy());
	}

	function getConst( v : Float ) : Reg {
		for( i in 0...current.consts.length )
			if( current.consts[i] == v ) {
				var g = current.globals;
				while( g != null ) {
					if( g.path == "__consts__" )
						break;
					g = g.next;
				}
				var p = g.pos + i;
				return new Reg(RConst, p >> 2, [COMPS[p & 3]]);
			}
		throw "Missing required const "+v;
	}

	function getConsts( va : Array<Float> ) : Reg {
		var pad = (va.length - 1) & 3;
		for( i in 0...current.consts.length - (va.length - 1) ) {
			if( (i >> 2) != (i + pad) >> 2 ) continue;
			var found = true;
			for( j in 0...va.length )
				if( current.consts[i + j] != va[j] ) {
					found = false;
					break;
				}
			if( found ) {
				var g = current.globals;
				while( g != null ) {
					if( g.path == "__consts__" )
						break;
					g = g.next;
				}
				var p = g.pos + i;
				return new Reg(RConst, p >> 2, defSwiz(TVec(va.length,VFloat)));
			}
		}
		throw "Missing required consts "+va;
	}

	function expr( e : TExpr ) : Reg {
		switch( e.e ) {
		case TConst(c):
			switch( c ) {
			case CInt(v):
				return getConst(v);
			case CFloat(f):
				return getConst(f);
			default:
				throw "assert " + c;
			}
		case TParenthesis(e):
			return expr(e);
		case TVarDecl(v, init):
			if( init != null )
				mov(reg(v), expr(init), v.type);
			return nullReg;
		case TBlock(el):
			var r = nullReg;
			for( e in el )
				r = expr(e);
			return r;
		case TVar(v):