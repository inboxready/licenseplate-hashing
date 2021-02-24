package h3d.shader;

class Outline2D extends ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var size : Vec2;
		@param @const var samples : Int;
		@param var color : Vec4;
		@param @c