package h2d.filter;

/**
	The base class for simple filters that don't need specialized render passes and rely completely on the shaders.

	Provides an easy interface to implement custom filters without going too deep into filter rendering process with render passes.

	Compatible shaders should extend from `h3d.shader.ScreenShader` and contain an input texture uniform, as well as assign `pixelColor` in fragment shader.

	Sample of a simple custom filter:
	```haxe
	class InvertColorShader extends h3d.shader.ScreenShader {
		static var SRC = {
			@param var texture : Sampler2D;

			function fragment() {
				var pixel : Vec4 = texture.get(calculatedUV);
				// Premultiply alpha to ensure correct transparency.
				pixelColor = vec4(