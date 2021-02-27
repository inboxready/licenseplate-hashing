package h3d.shader;

/**
	Screen space ambient occlusion.
	Uses "Scalable Ambient Obscurance" [McGuire12]
**/
class SAO extends ScreenShader {

	static var SRC = {

		@range(4,30) @const var numSamples : Int;
		@range(1,10) @const(16) var numSpiralTurns : Int;
		@const var useWorldUV : Bool;

		@ignore @param var depthTexture : Channel;
		@ignore @param var normalTexture : Channel3;
		@param var noiseTexture : Sampler2D;
		@param var noiseScale : Vec2;
		@range(0,10) @param var sampleRadius : Float;
		@range(0,10) @param var intensity : Float;
		@range(0,0.2) @param va