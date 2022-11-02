class GpuParticles extends SampleApp {

	var parts : h3d.parts.GpuParticles;
	var group : h3d.parts.GpuParticles.GpuPartGroup;
	var box : h3d.scene.Box;
	var tf : h2d.Text;
	var moving = false;
	var time = 0.;

	override function init() {
		super.init();
		parts = new h3d.parts.GpuParticles(s3d);

		var g = new h3d.parts.GpuParticles.GpuPartGroup(parts);

		g.emitMode = Cone;
		g.emitAngle = 0.5;
		g.emitDist = 0;

		g.fadeIn = 0.8;
		g.fadeOut = 0.8;
		g.fadePower = 10;
		g.gravity = 1;
		g.size = 0.1;
		g.sizeRand = 0.5;

		g.rotSpeed = 10;

		g.speed = 2;
		g.speedRand = 0.5;

		g.life = 2;
		g.lifeRand = 0.5;
		g.nparts = 10000;

		addSlider("