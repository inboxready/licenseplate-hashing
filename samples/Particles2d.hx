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
		// addButton("PartEmitMode.Point Demo", changeToPointDemo);
		// addButton("PartEmitMode.Point + emitDirectionAsAngle Demo", changeToPointAndDirectionAsAngleDemo);
		// addButton("PartEmitMode.Cone Demo", changeToConeDemo);
		// addButton("PartEmitMode.Box Demo", changeToBoxDemo);
		// addButton("PartEmitMode.Direction Demo", changeToDirectionDemo);
		// addButton("PartEmitMode.Direction + emitDirectionAsAngle Demo", changeToDirectionAndDirectionAsAngleDemo);

		changeToPointDemo();
	}

	function changeToPointDemo() {
		// clear();
		reset();

		// g = new ParticleGroup(particles);
		g.sizeRand = .2;
		g.life = 1;
		g.speed = 100;
		g.speedRand = 3;
		g.rotSpeed = 2;
		g.emitMode = PartEmitMode.Point;
		g.emitDist = 0;
		g.fadeIn = 0;
		g.fadeOut = 0;
		g.dx = cast s2d.width / 2;
		g.dy = cast s2d.height / 2;

		// particles.addGroup(g);
	}

	function changeToPointAndDirectionAsAngleDemo() {
		// clear();
		reset();

		// g = new ParticleGroup(particles);
		g.size = .8;
		g.sizeRand = .2;
		g.life = .5;
		g.speed = 100;
		g.speedRand = 3;
		g.emitMode = PartEmitMode.Point;
		g.emitDist = 0;
		g.fadeIn = 0;
		g.fadeOut = 0;
		g.dx = cast s2d.width / 2;
		g.dy = cast s2d.height / 2;

		// particles.addGroup(g);
	}

	function changeToConeDemo() {
		// clear();
		reset();

		// g = new ParticleGroup(particles);
		g.size = .2;
		g.gravity = 1;
		g.life = 5;
		g.speed = 100;
		g.speedRand = 3;
		g.emitMode = PartEmitMode.Cone;
		g.emitAngle = Math.PI;
		g.emitDist = 0;
		g.emitDistY = 0;
		g.fadeIn = 1;
		g.fadeOut = 1;
		g.dx = cast s2d.width / 2;
		g.dy = cast s2d.height / 2;

		// particles.addGroup(g);
	}

	function changeToBoxDemo() {
		// clear();
		reset();

		// g = new ParticleGroup(particles);
		g.size = .2;
		g.gravity = 1;
		g.life = 5;
		g.speed = 100;
		g.speedRand = 3;
		g.emitMode = PartEmitMode.Box;
		g.emitAngle = Math.PI;
		g.emitDist = s2d.width;
		g.emitDistY = s2d.height;
		g.dx = cast s2d.width / 2;

		// particles.addGroup(g);
	}

	function changeToDirectionDemo() {
		// clear();
		reset();

		// g = new ParticleGroup(particles);
		g.size = .2;
		g.gravity = 1;
		g.life = 5;
		g.speed = 100;
		g.speedRand = 3;
		g.emitMode = PartEmitMode.Direction;
		g.emitDist = s2d.width;
		g.emitAngle = Math.PI / 2;
		g.fadeOut = .5;

		// particles.addGroup(g);
	}

	function changeToDirectionAndDirectionAsAngleDemo() {
		// clear();
		reset();

		// g = new ParticleGroup(particles);
		g.size = .8;
		g.sizeRand = .2;
		g.life = 6;
		g.speed = 200;
		g.speedRand = 3;
		g.emitMode = PartEmitMode.Direction;
		g.emitDist = s2d.height;
		g.emitAngle = Math.PI / 4;
		g.fadeIn = 0;
		g.fadeOut = 0;


		// particles.addGroup(g);
	}

	static function main() {
		Res.initEmbed();
		new Particles2d();
	}

	function reset() {
		g.dx = 0;
		g.dy = 0;
		g.emitDist = 50.;
		g.emitDistY = 50.;
		g.emitAngle = -.5;
		g.emitSync = 0;
		g.emitDelay = 0;
		g.emitStartDist = 0.;

		g.life = 1;
		g.lifeRand = 0;

		g.sizeIncr = 0;
		g.incrX = true;
		g.incrY = true;
		g.size = 1;
		g.sizeRand = 0;

		g.speed = 50.;
		g.speedRand = 0;
		g.speedIncr = 0;
		g.gravity = 0;
		g.gravityAngle = 0;

		g.rotInit