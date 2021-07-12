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
		for (i in 0...len - 1) res += String.from