package hxd.fmt.grd;
import hxd.fmt.grd.Data;

// http://www.tonton-pixel.com/Photoshop%20Additional%20File%20Formats/gradients-file-format.html

class Reader {
	var i : haxe.io.Input;
	var version : Int;

	public function new(i) {
		this.i = i;
		i.bigEndian = true;
	}

	function readUnicode(input : haxe.io.Input, len : Int) : String {
		var res = "";
		for (i in 0...len - 1) res += String.fromCharCode(input.readInt16());
		input.readInt16();
		return res;
	}

	function parseValue(i : haxe.io.Input) : Dynamic {
		var type = i.readString(4);
		var value : Dynamic;
		switch (type) {
			case "Objc" : value = parseObj (i);
            case "VlLs" : value = parseList(i);
            case "doub" : value = i.readDouble();
            case "UntF" : i.readString(4); value = i.readDouble();
            case "TEXT" : value = readUnicode(i, i.readInt32());
            case "enum" : value = parseEnum(i);
            case "long" : value = i.readInt32();
            case "bool" : value = i.readByte();
            case "tdtd" : var len = i.readInt32(); value = { length : len, value : i.read(len) };
			default     : throw "Unhandled type \"" + type + "\"";
		}
		return value;
	}

	function parseObj(i : haxe.io.Input) : Dynamic {
		var len  = i.readInt32(); if (len == 0) len = 4;
		var name