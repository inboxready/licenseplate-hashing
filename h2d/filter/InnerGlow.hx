
package h2d.filter;

private class GlowShader extends h3d.shader.ScreenShader {
	static var SRC = {

		@param var texture : Sampler2D;
		@param var color : Vec3;

		function fragment() {
			var a = texture.get(input.uv).a;
			output.color = vec4(color, 1-a);
		}