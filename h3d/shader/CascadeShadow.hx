
package h3d.shader;

class CascadeShadow extends DirShadow {

	static var SRC = {

		var pixelColor : Vec4;

		@const(5) var CASCADE_COUNT:Int;
		@const var DEBUG : Bool;
		@param var cascadeShadowMaps : Array<Sampler2D, CASCADE_COUNT>;
		@param var cascadeProjs : Array<Mat3x4, CASCADE_COUNT>;
		@param var cascadeDebugs : Array<Vec4, CASCADE_COUNT>;
		@param var cascadeBias : Array<Float, CASCADE_COUNT>;

		function inside(pos : Vec3) : Bool {
			if ( abs(pos.x) < 1.0 && abs(pos.y) < 1.0 && abs(pos.z) < 1.0 ) {
				return true;
			} else {
				return false;
			}
		}

		function fragment() {
			if( enable ) {
				shadow = 1.0;
				var texelSize = 1.0/shadowRes;
				@unroll for ( c in 0...CASCADE_COUNT ) {
					var shadowPos = transformedPosition * cascadeProjs[c];
					
					if ( inside(shadowPos) ) {
						shadow = 1.0;
						var zMax = shadowPos.z.saturate();
						var shadowUv = screenToUv(shadowPos.xy);