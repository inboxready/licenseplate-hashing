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
		buffer = new h3d.Buffer(data.vertexCount, data.vertexStride, [LargeBuffer]);

		var entry = lib.resource.entry;

		var size = data.vertexCount * data.vertexStride * 4;
		var bytes = entry.fetchBytes(dataPosition + data.vertexPosition, size);
		buffer.uploadBytes(bytes, 0, data.vertexCount);

		indexCount = 0;
		indexesTriPos = [];
		for( n in data.indexCounts ) {
			indexesTriPos.push(Std.int(indexCount/3));
			indexCount += n;
		}
		var is32 = data.vertexCount > 0x10000;
		indexes = new h3d.Indexes(indexCount, is32);

		var size = (is32 ? 4 : 2) * indexCount;
		var bytes = entry.fetchBytes(dataPosition + data.indexPosition, size);
		indexes.uploadBytes(bytes, 0, indexCount);

		var pos = 0;
		for( f in data.vertexFormat ) {
			addBuffer(f.name, buffer, pos);
			pos += f.format.getSize();
		}

		if( normalsRecomputed != null )
			recomputeNormals(normalsRecomputed);

		for( name in bufferAliases.keys() )
			allocAlias(name);
	}

	function allocAlias( name : String ) {
		var alias = bufferAliases.get(name);
		var buffer = bufferCache.get(hxsl.Globals.allocID(alias.realName));
		if( buffer == null ) throw "Buffer " + alias.realName+" not found for alias " + name;
		if( buffer.offset + alias.offset > buffer.buffer.buffer.stride ) throw "Alias " + name+" for buffer " + alias.realName+" outside stride";
		addBuffer(name, buffer.buffer, buffer.offs