package h3d.mat;
import h3d.mat.Data;

@:allow(h3d.mat.Material)
#if !macro
@:build(hxd.impl.BitsBuilder.build())
#end
class Stencil {

	var maskBits  : Int = 0;
	var opBits    : Int = 0;

	@:bits(maskBits, 8) public var readMask : Int;
	@:bits(maskBits, 8) public var writeMask : Int;
	@:bits(m