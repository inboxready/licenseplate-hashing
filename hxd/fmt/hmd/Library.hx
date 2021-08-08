
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
		this.resource = res;
		this.header = header;
		cachedPrimitives = [];
		cachedAnimations = new Map();
		cachedSkin = new Map();
	}

	public function getData() {
		var entry = resource.entry;
		var b = haxe.io.Bytes.alloc(entry.size - header.dataPosition);
		entry.readFull(b, header.dataPosition, b.length);
		return b;
	}

	public function getDefaultFormat( stride : Int ) {
		var format = [
			new hxd.fmt.hmd.Data.GeometryFormat("position", DVec3),
		];
		var defs = [null];
		if( stride > 3 ) {
			format.push(new hxd.fmt.hmd.Data.GeometryFormat("normal", DVec3));
			defs.push(null);
		}
		if( stride > 6 ) {
			format.push(new hxd.fmt.hmd.Data.GeometryFormat("uv", DVec2));
			defs.push(null);
		}
		if( stride > 8 ) {
			format.push(new hxd.fmt.hmd.Data.GeometryFormat("color", DVec3));
			defs.push(new h3d.Vector(1, 1, 1));
		}
		if( stride > 11 )
			throw "Unsupported stride";
		return { format : format, defs : defs };
	}

	public function load( format : Array<GeometryFormat>, ?defaults : Array<h3d.Vector>, modelIndex = -1 ) {
		var vtmp = new h3d.Vector();
		var models = modelIndex < 0 ? header.models : [header.models[modelIndex]];
		var outVertex = new hxd.FloatBuffer();
		var outIndex = new hxd.IndexBuffer();
		var stride = 0;
		var mid = -1;
		for( f in format )
			stride += f.format.getSize();
		for( m in models ) {
			var geom = header.geometries[m.geometry];
			if( geom == null ) continue;
			for( mat in m.materials ) {
				if( mid < 0 ) mid = mat;
				if( mid != mat ) throw "Models have several materials";
			}
			var pos = m.position.toMatrix();
			var data = getBuffers(geom, format, defaults);
			var start = Std.int(outVertex.length / stride);
			for( i in 0...Std.int(data.vertexes.length / stride) ) {
				var p = i * stride;
				vtmp.x = data.vertexes[p++];
				vtmp.y = data.vertexes[p++];
				vtmp.z = data.vertexes[p++];
				vtmp.transform3x4(pos);
				outVertex.push(vtmp.x);
				outVertex.push(vtmp.y);
				outVertex.push(vtmp.z);
				for( j in 0...stride - 3 )
					outVertex.push(data.vertexes[p++]);
			}
			for( idx in data.indexes )
				outIndex.push(idx + start);
		}
		return { vertex : outVertex, index : outIndex };
	}

	@:noDebug
	public function getBuffers( geom : Geometry, format : Array<GeometryFormat>, ?defaults : Array<h3d.Vector>, ?material : Int ) {

		if( material == 0 && geom.indexCounts.length == 1 )
			material = null;

		var map = null, stride = 0;
		for( i in 0...format.length ) {
			var i = format.length - 1 - i;
			var f = format[i];
			var size  = f.format.getSize();
			var offset = 0;
			var found = false;
			for( f2 in geom.vertexFormat ) {
				if( f2.name == f.name ) {
					if( f2.format.getSize() < size )
						throw 'Requested ${f.name} data has only ${f2.format.getSize()} regs instead of $size';
					found = true;
					break;
				}
				offset += f2.format.getSize();
			}
			if( found ) {
				map = new FormatMap(size, offset, null, map);
			} else {
				var def = defaults == null ? null : defaults[i];
				if( def == null )
					throw 'Missing required ${f.name}';
				map = new FormatMap(size, 0, def, map);
			}
			stride += size;
		}

		var vsize = geom.vertexCount * geom.vertexStride * 4;
		var vbuf = haxe.io.Bytes.alloc(vsize);
		var entry = resource.entry;

		entry.readFull(vbuf, header.dataPosition + geom.vertexPosition, vsize);

		var dataPos = header.dataPosition + geom.indexPosition;
		var isSmall = geom.vertexCount <= 0x10000;
		var imult = isSmall ? 2 : 4;

		var isize;
		if( material == null )
			isize = geom.indexCount * imult;
		else {
			var ipos = 0;
			for( i in 0...material )
				ipos += geom.indexCounts[i];
			dataPos += ipos * imult;
			isize = geom.indexCounts[material] * imult;
		}
		var ibuf = haxe.io.Bytes.alloc(isize);
		entry.readFull(ibuf, dataPos, isize);

		var buf = new GeometryBuffer();
		if( material == null ) {
			buf.vertexes = new haxe.ds.Vector(stride * geom.vertexCount);
			buf.indexes = new haxe.ds.Vector(geom.indexCount);
			var w = 0;
			for( vid in 0...geom.vertexCount ) {
				var m = map;
				while( m != null ) {
					if( m.def == null ) {
						var r = vid * geom.vertexStride;
						for( i in 0...m.size )
							buf.vertexes[w++] = vbuf.getFloat((r + m.offset + i) << 2);
					} else {
						switch( m.size ) {
						case 1:
							buf.vertexes[w++] = m.def.x;
						case 2:
							buf.vertexes[w++] = m.def.x;
							buf.vertexes[w++] = m.def.y;
						case 3:
							buf.vertexes[w++] = m.def.x;
							buf.vertexes[w++] = m.def.y;
							buf.vertexes[w++] = m.def.z;
						default:
							buf.vertexes[w++] = m.def.x;
							buf.vertexes[w++] = m.def.y;
							buf.vertexes[w++] = m.def.z;
							buf.vertexes[w++] = m.def.w;
						}
					}
					m = m.next;
				}
			}
			if( isSmall ) {
				var r = 0;
				for( i in 0...buf.indexes.length )
					buf.indexes[i] = ibuf.get(r++) | (ibuf.get(r++) << 8);
			} else {
				for( i in 0...buf.indexes.length )
					buf.indexes[i] = ibuf.getInt32(i << 2);
			}
		} else {
			var icount = geom.indexCounts[material];
			var vmap = new haxe.ds.Vector(geom.vertexCount);
			var vertexes = new hxd.FloatBuffer();
			buf.indexes = new haxe.ds.Vector(icount);
			var r = 0, vcount = 0;
			for( i in 0...buf.indexes.length ) {
				var vid = isSmall ? (ibuf.get(r++) | (ibuf.get(r++) << 8)) : ibuf.getInt32(i<<2);
				var rid = vmap[vid];
				if( rid == 0 ) {
					rid = ++vcount;
					vmap[vid] = rid;
					var m = map;
					while( m != null ) {
						if( m.def == null ) {
							var r = vid * geom.vertexStride;
							for( i in 0...m.size )
								vertexes.push(vbuf.getFloat((r + m.offset + i) << 2));
						} else {
							switch( m.size ) {
							case 1:
								vertexes.push(m.def.x);
							case 2:
								vertexes.push(m.def.x);
								vertexes.push(m.def.y);
							case 3:
								vertexes.push(m.def.x);
								vertexes.push(m.def.y);
								vertexes.push(m.def.z);
							default:
								vertexes.push(m.def.x);
								vertexes.push(m.def.y);
								vertexes.push(m.def.z);
								vertexes.push(m.def.w);
							}
						}
						m = m.next;
					}
				}
				buf.indexes[i] = rid - 1;
			}
			#if neko
			buf.vertexes = haxe.ds.Vector.fromArrayCopy(vertexes.getNative());
			#else
			buf.vertexes = haxe.ds.Vector.fromData(vertexes.getNative());
			#end
		}

		return buf;
	}

	function makePrimitive( id : Int ) {
		var p = cachedPrimitives[id];
		if( p != null ) return p;
		p = new h3d.prim.HMDModel(header.geometries[id], header.dataPosition, this);
		p.incref(); // Prevent from auto-disposing
		cachedPrimitives[id] = p;
		return p;
	}

	public function dispose() {
		for( p in cachedPrimitives )
			if( p != null )
				p.decref();
		cachedPrimitives = [];
	}

	function makeMaterial( model : Model, mid : Int, loadTexture : String -> h3d.mat.Texture ) {
		var m = header.materials[mid];
		var mat = h3d.mat.MaterialSetup.current.createMaterial();
		mat.name = m.name;
		mat.model = resource;
		mat.blendMode = m.blendMode;
		var props = h3d.mat.MaterialSetup.current.loadMaterialProps(mat);
		if( props == null ) props = mat.getDefaultModelProps();
		#if hide
		if( (props:Dynamic).__ref != null ) {
			try {
				if ( setupMaterialLibrary(mat, hxd.res.Loader.currentInstance.load((props:Dynamic).__ref).toPrefab(), (props:Dynamic).name) )
					return mat;
			} catch( e : Dynamic ) {
			}
		}
		#end
		if( m.diffuseTexture != null ) {
			mat.texture = loadTexture(m.diffuseTexture);
			if( mat.texture == null ) mat.texture = h3d.mat.Texture.fromColor(0xFF00FF);
		}
		if( m.specularTexture != null )
			mat.specularTexture = loadTexture(m.specularTexture);
		if( m.normalMap != null )
			mat.normalMap = loadTexture(m.normalMap);
		mat.props = props;
		return mat;
	}

	@:access(h3d.anim.Skin)
	function makeSkin( skin : Skin, geom : Geometry ) {
		var s = cachedSkin.get(skin.name);
		if( s != null )
			return s;
		s = new h3d.anim.Skin(skin.name, 0, geom.props != null && geom.props.indexOf(FourBonesByVertex) >= 0 ? 4 : 3 );
		s.namedJoints = new Map();
		s.allJoints = [];
		s.boundJoints = [];
		s.rootJoints = [];
		for( joint in skin.joints ) {
			var j = new h3d.anim.Skin.Joint();
			j.name = joint.name;
			j.index = s.allJoints.length;
			j.defMat = joint.position.toMatrix();
			if( joint.bind >= 0 ) {
				j.bindIndex = joint.bind;
				j.transPos = joint.transpos.toMatrix(true);
				s.boundJoints[j.bindIndex] = j;
			}
			if( joint.parent >= 0 ) {
				var p = s.allJoints[joint.parent];
				p.subs.push(j);
				j.parent = p;
			} else
				s.rootJoints.push(j);
			s.allJoints.push(j);
			s.namedJoints.set(j.name, j);
		}
		if( skin.split != null ) {
			s.splitJoints = [];
			for( ss in skin.split )
				s.splitJoints.push( { material : ss.materialIndex, joints : [for( j in ss.joints ) s.allJoints[j]] } );
		}
		cachedSkin.set(skin.name, s);
		return s;
	}

	public function getModelProperty<T>( objName : String, p : Property<T>, ?def : Null<T> ) : Null<T> {
		for( m in header.models )
			if( m.name == objName ) {
				if( m.props != null )
					for( pr in m.props )
						if( pr.getIndex() == p.getIndex() )
							return pr.getParameters()[0];
				return def;
			}
		if( def == null )
			throw 'Model ${objName} not found';
		return def;
	}

	#if !dataOnly
	public function makeObject( ?loadTexture : String -> h3d.mat.Texture ) : h3d.scene.Object {
		if( loadTexture == null )
			loadTexture = function(_) return h3d.mat.Texture.fromColor(0xFF00FF);
		if( header.models.length == 0 )
			throw "This file does not contain any model";
		var objs = [];
		for( m in header.models ) {
			var obj : h3d.scene.Object;
			if( m.geometry < 0 ) {
				obj = new h3d.scene.Object();
			} else {
				var prim = makePrimitive(m.geometry);
				if( m.skin != null ) {
					var skinData = makeSkin(m.skin, header.geometries[m.geometry]);
					skinData.primitive = prim;
					obj = new h3d.scene.Skin(skinData, [for( mat in m.materials ) makeMaterial(m, mat, loadTexture)]);
				} else if( m.materials.length == 1 )
					obj = new h3d.scene.Mesh(prim, makeMaterial(m, m.materials[0],loadTexture));
				else
					obj = new h3d.scene.MultiMaterial(prim, [for( mat in m.materials ) makeMaterial(m, mat, loadTexture)]);
			}
			obj.name = m.name;
			obj.defaultTransform = m.position.toMatrix();
			objs.push(obj);
			var p = objs[m.parent];
			if( p != null ) p.addChild(obj);
		}
		var o = objs[0];
		if( o != null ) o.modelRoot = true;
		return o;
	}
	#end

	public function loadAnimation( ?name : String ) : h3d.anim.Animation {

		var a = cachedAnimations.get(name == null ? "" : name);
		if( a != null )
			return a;

		var a = null;
		if( name == null ) {
			if( header.animations.length == 0 )
				return null;
			a = header.animations[0];
		} else {
			for( a2 in header.animations )
				if( a2.name == name ) {
					a = a2;
					break;
				}
			if( a == null )
				throw 'Animation $name not found !';
		}

		var l = header.version <= 2 ? makeLinearAnimation(a) : makeAnimation(a);
		l.speed = a.speed;
		l.loop = a.loop;
		if( a.events != null ) l.setEvents(a.events);
		l.resourcePath = resource.entry.path;
		cachedAnimations.set(a.name, l);
		if( name == null ) cachedAnimations.set("", l);
		return l;
	}

	function makeAnimation( a : Animation ) {
		var b = new h3d.anim.BufferAnimation(a.name, a.frames, a.sampling);

		var stride = 0;
		var singleFrames = [];
		var otherFrames = [];
		for( o in a.objects ) {
			var c = b.addObject(o.name, 0);
			var sm = 1;
			if( o.flags.has(SingleFrame) ) {
				c.layout.set(SingleFrame);
				singleFrames.push(c);
				sm = 0;
			} else
				otherFrames.push(c);
			if( o.flags.has(HasPosition) ) {
				c.layout.set(Position);
				stride += 3 * sm;
			}
			if( o.flags.has(HasRotation) ) {
				c.layout.set(Rotation);
				stride += 3 * sm;
			}
			if( o.flags.has(HasScale) ) {
				c.layout.set(Scale);
				stride += 3 * sm;
			}
			if( o.flags.has(HasUV) ) {
				c.layout.set(UV);
				stride += 2 * sm;
			}
			if( o.flags.has(HasAlpha) ) {
				c.layout.set(Alpha);
				stride += sm;
			}
			if( o.flags.has(HasProps) ) {
				for( i in 0...o.props.length ) {
					var c = c;
					if( i > 0 ) {
						c = b.addObject(o.name, 0);
						if( sm == 0 ) singleFrames.push(c) else otherFrames.push(c);
					}
					c.layout.set(Property);
					c.propName = o.props[i];
					stride += sm;
				}
			}
		}

		// assign data offsets
		var pos = 0;
		for( b in singleFrames ) {
			b.dataOffset = pos;
			pos += b.getStride();
		}
		var singleStride = pos;
		for( b in otherFrames ) {
			b.dataOffset = pos;