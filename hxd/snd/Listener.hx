package hxd.snd;

class Listener {

	public var position : h3d.Vector;
	public var direction : h3d.Vector;
	public var velocity : h3d.Vector;
	public var up  : h3d.Vector;

	public function new() {
		position = new h3d.Vector();
		velocity = new h3d.Vector();
		direction = new h3d.Vector(1,  0, 0);
		up = new h3d.Vector(0,  0,