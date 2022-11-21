class Pbr extends SampleApp {

	var hue : Float;
	var saturation : Float;
	var brightness : Float;
	var color : h2d.Bitmap;
	var sphere : h3d.scene.Mesh;
	var grid : h3d.scene.Object;

	var env : h3d.scene.pbr.Environment;
	var renderer : h3d.scene.pbr.Renderer;

	function new() {
		h3d.mat.MaterialSetup.current = new h3d.mat.PbrMaterialSetup();
		super();
	}

	override function init() {
		super.init();

		new h3d.scene.CameraController(5.5, s3d);

		#if flash
		new h2d.Text(getFont(), s2d).text = "Not supported on this platform (requires render to mipmap target and fragment textureCubeLod support)";
		return;
		#end

		#if j