package hxd.fmt.pak;
import hxd.fmt.pak.Data;

class Build {

	var fs : hxd.fs.LocalFileSystem;
	var out : { bytes : Array<haxe.io.Bytes>, size : Float };
	var configuration : String;
	var nextPath : String;

	public var excludedExt : Array<String> = [];
	public var excludedNames : Array<String> = [];
	public var excludePath : Array<String> = [];
	public var includePath : Array<String> = [];
	public var resPath : String = "res";
	public var outPrefix : String;
	public var pakDiff = false;
	public var checkJPG = false;
	public var checkOGG = false;

	function new() {
	}

	function c