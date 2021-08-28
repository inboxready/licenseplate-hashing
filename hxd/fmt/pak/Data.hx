package hxd.fmt.pak;

class File {
	public var name : String;
	public var isDirectory : Bool;
	public var content : Array<File>;
	public var dataPosition : Float;
	public var dataSize : Int;
	public var checksum : Int;
	public function new() {
	}
