
package hxd.fmt.hmd;
import hxd.fmt.hmd.Data;

class Reader {

	static var BLEND = Type.allEnums(h2d.BlendMode);
	static var CULLING = Type.allEnums(h3d.mat.Data.Face);

	var i : haxe.io.Input;
	var version : Int;

	public function new(i) {
		this.i = i;
	}

	function readProperty() {
		switch( i.readByte() ) {
		case 0:
			return CameraFOVY(i.readFloat());
		case 1:
			throw "Obsolete HasMaterialFlags";
		case 2:
			return HasExtraTextures;
		case 3:
			return FourBonesByVertex;
		case unk:
			throw "Unknown property #" + unk;
		}
	}

	function readProps() {
		if( version == 1 )
			return null;
		var n = i.readByte();
		if( n == 0 )
			return null;
		return [for( i in 0...n ) readProperty()];
	}

	function readName() {
		var b = i.readByte();
		if( b == 0xFF ) return null;
		return i.readString(b);
	}


	static var HMD_STRINGS : Map<String,String>;

	// make sure some strings are reused between models
	// in order to prevent many similar String to be kept into memory
	function readCachedName() {
		var name = readName();
		if( name == null ) return null;
		if( HMD_STRINGS == null )
			HMD_STRINGS = new Map<String,String>();
		var n = HMD_STRINGS.get(name);
		if( n != null ) return n;
		HMD_STRINGS.set(name,name);
		return name;
	}

	function readPosition(hasScale=true) {
		var p = new Position();
		p.x = i.readFloat();
		p.y = i.readFloat();
		p.z = i.readFloat();
		p.qx = i.readFloat();
		p.qy = i.readFloat();
		p.qz = i.readFloat();
		if( hasScale ) {
			p.sx = i.readFloat();
			p.sy = i.readFloat();
			p.sz = i.readFloat();
		} else {
			p.sx = 1;
			p.sy = 1;
			p.sz = 1;
		}
		return p;
	}

	function readBounds() {
		var b = new h3d.col.Bounds();
		b.xMin = i.readFloat();
		b.yMin = i.readFloat();
		b.zMin = i.readFloat();
		b.xMax = i.readFloat();
		b.yMax = i.readFloat();
		b.zMax = i.readFloat();
		return b;
	}

	function readSkin() {
		var name = readCachedName();
		if( name == null )
			return null;
		var s = new Skin();
		s.props = readProps();
		s.name = name;
		s.joints = [];
		for( k in 0...i.readUInt16() ) {
			var j = new SkinJoint();
			j.props = readProps();
			j.name = readCachedName();
			var pid = i.readUInt16();
			var hasScale = pid & 0x8000 != 0;
			if( hasScale ) pid &= 0x7FFF;
			j.parent = pid - 1;
			j.position = readPosition(hasScale);
			j.bind = i.readUInt16() - 1;
			if( j.bind >= 0 )
				j.transpos = readPosition(hasScale);
			s.joints.push(j);
		}
		var count = i.readByte();
		if( count > 0 ) {
			s.split = [];
			for( k in 0...count ) {
				var ss = new SkinSplit();
				ss.materialIndex = i.readByte();
				ss.joints = [for( k in 0...i.readByte() ) i.readUInt16()];
				s.split.push(ss);
			}
		}
		return s;
	}

	public function readHeader( fast = false ) : Data {
		var d = new Data();
		var h = i.readString(3);