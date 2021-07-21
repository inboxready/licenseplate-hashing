package hxd.fmt.hmd;

@:enum abstract GeometryDataFormat(Int) {

	public var DFloat = 1;
	public var DVec2 = 2;
	public var DVec3 = 3;
	public var DVec4 = 4;
	public var DBytes4 = 9;

	inline function new(v) {
		this