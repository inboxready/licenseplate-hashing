package h3d.prim;

class HMDModel extends MeshPrimitive {

	var data : hxd.fmt.hmd.Data.Geometry;
	var dataPosition : Int;
	var indexCount : Int;
	var indexesTriPos : Array<Int>;
	var lib : hxd.fmt.hmd.Library;
	var curMaterial : Int;
	var collider : h3d.col.Collider;
	var normalsRecomputed : String;
	var bufferAliases : Map<String,{ realName : String, offset : Int }> = new Map();

	public function new(data, dataPos, lib) {
		this.data = data;
		this.dataPosition = dataPos;
		this.lib = lib;
	}

	override function triCount() {
		return Std.int(data.indexCount / 3);
	}

	override function vertexCount() {
		return data.vertexCount;
	}

	override function getBounds() {
		return data.bounds;
	}

	override function selectMaterial( i : Int ) {
		curMaterial = i;
	}

	override function getMaterialIndexes(material:Int):{count:Int, start:Int} {
		return { start : indexesTriPos[material]*3, count : data.indexCounts[material] };
	}

	public function getDataBuffers(fmt, ?defaults,?material) {
		return lib.getBuffers(data, fmt, defaults, material);
	}

	public function loadSkin(skin) {
		lib.loadSkin(data, skin);
	}

	public function addAlias( name : String, realName : String, offset = 0 ) {
		var old = bufferAliases.get(name);
		if( old != null ) {
			if( old.realName != realName || old.offset != offset ) throw "Conflicting alias "+name;
			return;
		}
		bufferAliases.set(name, {realName : realName, offset : offset });
		// already allocated !
		if( bufferCache != null ) allocAlias(name);
	}

	override function alloc(engine:h3d.Engine) {
		dispose();
		buffer = new h3d.Buffer(data.vertexCount, data.vertexStride, [La