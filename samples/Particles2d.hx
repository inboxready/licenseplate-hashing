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
		addCheck("Loop", function() return g.emitLoop, function(v) { g.emitLoop = v; });
		addCheck("Move", function() return moving, function(v) moving = v);
		addCheck("Relative", function() return g.isRelative, function(v) g.isRelative = v);
		addCheck("Dir as Angle", function() return g.emitDirectionAsAngle, function(v) { g.emitDirectionAsAngle = v; g.texture = v ? arrow : square; });
		addCheck("RebuildMode", function() return g.rebuildOnChange, function(v) { g.rebuildOnChange = v; });

		addChoice("EmitMode", ["Point A", "Point B", "Cone", "Box", "Dir A", "Dir B"], function (v) {
			switch(v) {
				case 0: changeToPointDemo();
				case 1: changeToPointAndDirectionAsAngleDemo();
				case 2: changeToConeDemo();
				case 3: changeToBoxDemo();
				case 4: changeToDirectionDemo();
				case 5: changeToDirectionAndDirectionAsAngleDemo();
			}
		});
		// addButton("PartEmitMode.Point Demo", ch