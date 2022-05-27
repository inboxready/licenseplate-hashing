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
			var r = reg(v);
			switch( v.type ) {
			case TBytes(n):
				// multiply by 255 on read
				var ro = allocReg();
				var c = getConst(255);
				var sw = [];
				for( i in 0...n ) {
					sw.push(COMPS[i]);
					if( i > 0 ) c.swiz.push(c.swiz[0]);
				}
				op(OMul(swiz(ro, sw), swiz(r, sw), c));
				return ro;
			default:
			}
			return r;
		case TBinop(bop, e1, e2):
			return binop(bop, e.t, e1, e2);
		case TCall(c, args):
			switch( c.e ) {
			case TGlobal(g):
				return global(g, args, e.t);
			default:
				throw "TODO CALL " + e.e;
			}
		case TArray(ea, index):
			switch( index.e ) {
			case TConst(CInt(v)):
				var r = expr(ea);
				var stride = switch( ea.t ) {
				case TArray(TSampler2D | TSamplerCube, _): 4;
				case TArray(t, _): Tools.size(t);
				default: throw "assert " + e.t;
				};
				var index = v * stride;
				var swiz = null;
				if( stride < 4 ) {
					swiz = [];
					for( i in 0...stride )
						swiz.push(COMPS[(i + index) & 3]);
				} else if( index & 3 != 0 ) throw "assert"; // not register-aligned !
				return new Reg(r.t, r.index + (index>>2), swiz);
			default:
				var r = expr(ea);
				var delta = 0;
				// remove ToInt and extract delta when the form is [int(offset) * stride + delta] as produced by Flatten
				switch( index.e ) {
				case TBinop(OpAdd, { e : TBinop(OpMult,{ e : TCall({ e : TGlobal(ToInt) },[epos]) },stride) } , { e : TConst(CInt(d)) } ):
					delta = d;
					index = { e : TBinop(OpMult, epos, stride), t : TFloat, p : index.p };
				case TBinop(OpMult,{ e : TCall({ e : TGlobal(ToInt) },[epos]) },stride):
					index = { e : TBinop(OpMult, epos, stride), t : TFloat, p : index.p };
				case TBinop(OpAdd, { e : TCall({ e : TGlobal(ToInt) },[epos]) }, { e : TConst(CInt(d)) } ):
					delta = d;
					index = epos;
				case TCall({ e : TGlobal(ToInt) },[epos]):
					index = epos;
				default:
				}
				var i = expr(index);
				if( r.swiz != null || r.access != null ) throw "assert";
				if( i.swiz == null || i.swiz.length != 1 || i.access != null ) throw "assert";
				var out = allocReg();
				op(OMov(out, new Reg(i.t, i.index, null, new RegAccess(r.t, i.swiz[0], r.index + delta))));
				return out;
			}
		case TSwiz(e, regs):
			var r = expr(e);
			return swiz(r, [for( r in regs ) COMPS[r.getIndex()]]);
		case TIf( cond, { e : TDiscard }, null ):
			switch( cond.e ) {
			case TBinop(bop = OpLt | OpGt, e1, e2) if( e1.t == TFloat ):
				if( bop == OpGt ) {
					var tmp = e1;
					e1 = e2;
					e2 = e1;
				}
				var r = allocReg(TFloat);
				op(OSub(r, expr(e1), expr(e2)));
				op(OKil(r));
				return nullReg;
			default:
				throw "Discard cond not supported " + e.e+ " "+e.p;
			}
		case TUnop(uop, e):
			switch( uop ) {
			case OpNeg:
				var r = allocReg(e.t);
				op(ONeg(r, expr(e)));
				return r;
			default:
			}
		case TIf(econd, eif, eelse):
			switch( econd.e ) {
			case TBinop(bop, e1, e2) if( e1.t == TFloat ):
				inline function cop(f) {
					op(f(expr(e1), expr(e2)));
					expr(eif);
					if( eelse != null ) {
						op(OEls);
						expr(eelse);
					}
					op(OEif);
					return nullReg;
				}
				switch( bop ) {
				case OpEq:
					return cop(OIfe);
				case OpNotEq:
					return cop(OIfe);
				case OpGt:
					return cop(OIfg);
				case OpLt:
					return cop(OIfl);
				default:
					throw "Conditional operation not supported " + bop+" " + econd.p;
				}
			default:
			}
			throw "Conditional not supported " + econd.e+" " + econd.p;
		case TMeta(_, _, e):
			return expr(e);
		default:
			throw "Expression '" + Printer.toString(e)+"' not supported in AGAL "+e.p;
		}
		return null;
	}

	function binop( bop, et : Type, e1 : TExpr, e2 : TExpr ) {
		inline function std(bop) {
			var r = allocReg(et);
			op(bop(r, expr(e1), expr(e2)));
			return r;
		}
		inline function compare(bop,e1,e2) {
			var r = allocReg(et);
			op(bop(r, expr(e1), expr(e2)));
			return r;
		}
		switch( bop ) {
		case OpAdd: return std(OAdd);
		case OpSub: return std(OSub);
		case OpDiv: return std(ODiv);
		case OpMod:
			var tmp = allocReg(e2.t);
			op(OMov(tmp, expr(e2)));
			var r = allocReg(et);
			op(ODiv(r, expr(e1), tmp));
			op(OFrc(r, r));
			op(OMul(r, r, tmp));
			return r;
		case OpAssign:
			var r = expr(e1);
			mov(r, expr(e2), e1.t);
			return r;
		case OpAssignOp(op):
			var r1 = expr(e1);
			mov(r1, expr( { e : TBinop(op, e1, e2), t : e1.t, p : e1.p } ), e1.t);
			return r1;
		case OpMult:
			var r = allocReg(et);
			var r1 = expr(e1)