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

	function command( cmd : String, ?args : Array<String> ) {
		var ret = Sys.command(cmd, args);
		if( ret != 0 )
			throw cmd + " has failed with exit code " + ret;
	}

	function buildRec( path : String ) {

		if( path != "" ) {
			if( excludePath.indexOf(path) >= 0 ) return null;
		}

		var dir = resPath + (path == "" ? "" : "/" + path);
		var f = new File();
		#if !dataOnly
		hxd.System.timeoutTick();
		#end
		f.name = path.split("/").pop();
		if( sys.FileSystem.isDirectory(dir) ) {
			var prevPath = nextPath;
			nextPath = path == "" ? "<root>" : path;
			f.isDirectory = true;
			f.content = [];
			for( name in sys.FileSystem.readDirectory(dir) ) {
				if( excludedNames.indexOf(name)>=0 )
					continue;
				var fpath = path == "" ? name : path+"/"+name;
				if( name.charCodeAt(0) == ".".code )
					continue;
				var s = buildRec(fpath);
				if( s != null ) f.content.push(s);
			}
			nextPath