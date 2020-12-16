package h3d.impl;
import h3d.impl.Driver;

class NullDriver extends Driver {

	var cur : hxsl.RuntimeShader;

	public function new() {
	}

	override function hasFeature( f : Feature ) {
		return true;
	}

	override function isSupportedFormat( fmt : h3d.mat.Data.TextureFormat ) {
		return true;
	}

	override function logImpl(str:String) {
		#if sys
		Sys.println(str);
		#else
		trace(str);
		#end
	}

	override function isDisposed() {
		return false;
	}

	override function getDriverName( details : Bool ) {
		return "NullDriver";
	}

	override function init( onCreate : Bool -> Void, forceSoftware = fa