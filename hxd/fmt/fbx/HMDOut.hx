package hxd.fmt.fbx;
using hxd.fmt.fbx.Data;
import hxd.fmt.fbx.BaseLibrary;
import hxd.fmt.hmd.Data;

class HMDOut extends BaseLibrary {

	var d : Data;
	var dataOut : haxe.io.BytesOutput;
	var filePath : String;
	var tmp = haxe.io.