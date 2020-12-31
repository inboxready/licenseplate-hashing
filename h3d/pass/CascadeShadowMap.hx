package h3d.pass;

class CascadeShadowMap extends DirShadowMap {

	var cshader : h3d.shader.CascadeShadow;
	var lightCameras : Array<h3d.Camera> = [];
	var currentCascadeIndex = 0;

	public var pow : Float = 1.0;
	public var firstCascadeSize : Float = 10.0;
	public var castingMaxDist : Float = 0.0;
	public var cascade(default, set) = 1;
	public function set_cascade(v) {
		cascade = v;
		lightCameras = [];
		for ( i in 0...cascade ) {
			lightCameras.push(new h3d.Camera())