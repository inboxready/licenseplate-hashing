import h3d.mat.Texture;
import h2d.Graphics;
import h2d.Particles;
import hxd.Res;

class Particles2d extends SampleApp {
	var g : ParticleGroup;
	var particles : Particles;
	var movableParticleGroup : ParticleGroup;
	var time : Float;

	var arrow : Texture;
	var square : Texture;
	var moving : Bool = false;

	override function init() {
		super.init();

		square = null;// h2d.Tile.fromColor(0xFFFFFF, 16, 16).getTexture();
		arrow = Res.arrow.toTexture();

		particles = new Particles(s2d);
		g = new ParticleGroup(particles);
		particles.addGroup(g);

		addSlider("Amount", function() return g.nparts, function(v) g.nparts = Std.int(v), 1, 1000);
		addCheck("Sort", function() return g.sortMode == Dynamic, function(v) g.sortMode = v ? Dynamic : None);
		addCheck(