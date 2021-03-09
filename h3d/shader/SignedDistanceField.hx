package h3d.shader;

class SignedDistanceField extends hxsl.Shader {

	static var SRC = {

		@:import h3d.shader.Base2d;

		// Mode of operation - single-channel or multi-channel.
		// 0123 = RGBA, evertyhing else is MSDF.
		@const var channel : Int = 0;
		/**
			Use automatic edge smoothing based on derivatives.
		**/
		@const var autoSmoothing : Bool = false;
		/**
			Variable used to determine the edge of the field. ( default : 0.5 ) 
			Can be used to provide cheaper Outline for Text compared to Filte