
package hxd.fmt.blend;

// Ported from https://github.com/armory3d/blend


class Blend {

	public var pos:Int;
	var bytes: haxe.io.Bytes;

	// Header
	public var version:String;
	public var pointerSize:Int;
	public var littleEndian:Bool;
	// Data
	public var blocks:Array<Block> = [];
	public var dna:Dna;

	public function new(bytes: haxe.io.Bytes) {
		this.bytes = bytes;
		this.pos = 0;

		if (readChars(7) == 'BLENDER') parse();
		// else decompress();
	}

	public function dir(type:String):Array<String> {
		// Return structure fields
		var typeIndex = getTypeIndex(dna, type);
		if (typeIndex == -1) return null;
		var ds = getStruct(dna, typeIndex);
		var fields:Array<String> = [];
		for (i in 0...ds.fieldNames.length) {
			var nameIndex = ds.fieldNames[i];
			var typeIndex = ds.fieldTypes[i];
			fields.push(dna.types[typeIndex] + ' ' + dna.names[nameIndex]);
		}
		return fields;
	}

	public function get(type:String):Array<Handle> {
		// Return all structures of type
		var typeIndex = getTypeIndex(dna, type);
		if (typeIndex == -1) return null;
		var ds = getStruct(dna, typeIndex);
		var handles:Array<Handle> = [];
		for (b in blocks) {
			if (dna.structs[b.sdnaIndex].type == typeIndex) {
				var h = new Handle();
				handles.push(h);
				h.block = b;
				h.ds = ds;
			}
		}
		return handles;
	}

	public static function getStruct(dna:Dna, typeIndex:Int):DnaStruct {
		for (ds in dna.structs) if (ds.type == typeIndex) return ds;
		return null;
	}

	public static function getTypeIndex(dna:Dna, type:String):Int {
		for (i in 0...dna.types.length) if (type == dna.types[i]) { return i; }
		return -1;
	}

	function parse() {

		// Pointer size: _ 32bit, - 64bit
		pointerSize = readChar() == '_' ? 4 : 8;

		// v - little endian, V - big endian
		littleEndian = readChar() == 'v';
		if (littleEndian) {
			read16 = read16LE;
			read32 = read32LE;
		}
		else {
			read16 = read16BE;
			read32 = read32BE;
		}

		version = readChars(3);

		// Reading file blocks
		// Header - data
		while (pos < bytes.length) {

			align();
