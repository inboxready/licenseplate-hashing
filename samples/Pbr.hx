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

		#if js
		if( !engine.driver.hasFeature(ShaderModel3) ) {
			new h2d.Text(getFont(), s2d).text = "WebGL 2.0 support required and not available on this browser.";
			return;
		}
		#end

		var sp = new h3d.prim.Sphere(1, 128, 128);
		sp.addNormals();
		sp.addUVs();

		var bg = new h3d.scene.Mesh(sp, s3d);
		bg.scale(10);
		bg.material.mainPass.culling = Front;
		bg.material.mainPass.setPassName("overlay");

		fui = new h2d.Flow(s2d);
		fui.y = 5;
		fui.verticalSpacing = 5;
		fui.layout = Vertical;

		var envMap = new h3d.mat.Texture(512, 512, [Cube]);
		inline function set(face:Int, res:hxd.res.Image) {
			var pix = res.getPixels();
			envMap.uploadPixels(pix, 0, face);
		}
		set(0, hxd.Res.front);
		set(1, hxd.Res.back);
		set(2, hxd.Res.right);
		set(3, hxd.Res.left);
		set(4, hxd.Res.top);
		set(5, hxd.Res.bottom);

		var axis = new h3d.scene.Graphics(s3d);
		axis.lineStyle(2, 0xFF0000);
		axis.lineTo(2, 0, 0);
		axis.lineStyle(2, 0x00FF00);
		axis.moveTo(0, 0, 0);
		axis.lineTo(0, 2, 0);
		axis.lineStyle(2, 0x0000FF);
		axis.moveTo(0, 0, 0);
		axis.lineTo(0, 0, 2);

		axis.material.props = h3d.mat.MaterialSetup.current.getDefaults("ui");
		axis.visible = false;
		axis.material.mainPass.depthWrite = true;

		env = new h3d.scene.pbr.Environment(envMap);
		env.compute();

		renderer = cast(s3d.renderer, h3d.scene.pbr.Renderer)