package hxd.fmt.hmd;

@:enum abstract GeometryDataFormat(Int) {

	public var DFloat = 1;
	public var DVec2 = 2;
	public var DVec3 = 3;
	public var DVec4 = 4;
	public var DBytes4 = 9;

	inline function new(v) {
		this = v;
	}

	public inline function getSize() {
		return this & 7;
	}

	public inline function toInt() {
		return this;
	}

	public function toString() {
		return switch( new GeometryDataFormat(this) ) {
		case DFloat: "DFloat";
		case DVec2: "DVec2";
		case DVec3: "DVec3";
		case DVec4: "DVec4";
		case DBytes4: "DBytes4";
		}
	}

	public static inline function fromInt( v : Int ) : GeometryDataFormat {
		return new GeometryDataFormat(v);
	}
}

typedef DataPosition = Int