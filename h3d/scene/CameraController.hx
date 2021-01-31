
package h3d.scene;

class CameraController extends h3d.scene.Object {

	public var distance(get, never) : Float;
	public var targetDistance(get, never) : Float;
	public var theta(get, never) : Float;
	public var phi(get, never) : Float;
	public var fovY(get, never) : Float;
	public var target(get, never) : h3d.col.Point;

	public var friction = 0.4;
	public var rotateSpeed = 1.;
	public var zoomAmount = 1.15;
	public var fovZoomAmount = 1.1;
	public var panSpeed = 1.;
	public var smooth = 0.6;
	public var minDistance : Float = 0.;
	public var maxDistance : Float = 1e20;

	public var lockZPlanes = false;

	var scene : h3d.scene.Scene;
	var pushing = -1;
	var pushX = 0.;
	var pushY = 0.;
	var pushStartX = 0.;
	var pushStartY = 0.;
	var moveX = 0.;
	var moveY = 0.;
	var pushTime : Float;
	var curPos = new h3d.Vector();
	var curOffset = new h3d.Vector();
	var targetPos = new h3d.Vector(10. / 25., Math.PI / 4, Math.PI * 5 / 13);
	var targetOffset = new h3d.Vector(0, 0, 0, 0);

	public function new(?distance,?parent) {
		super(parent);
		name = "CameraController";
		set(distance);
		curPos.load(targetPos);
		curOffset.load(targetOffset);
	}

	inline function get_distance() return curPos.x / curOffset.w;
	inline function get_targetDistance() return targetPos.x / targetOffset.w;
	inline function get_theta() return curPos.y;
	inline function get_phi() return curPos.z;
	inline function get_fovY() return curOffset.w;
	inline function get_target() return curOffset.toPoint();

	/**
		Set the controller parameters.
		Distance is ray distance from target.
		Theta and Phi are the two spherical angles
		Target is the target position
	**/
	public function set(?distance:Float, ?theta:Float, ?phi:Float, ?target:h3d.col.Point, ?fovY:Float) {
		if( theta != null )
			targetPos.y = theta;
		if( phi != null )
			targetPos.z = phi;
		if( target != null )
			targetOffset.set(target.x, target.y, target.z, targetOffset.w);
		if( fovY != null )
			targetOffset.w = fovY;
		if( distance != null )
			targetPos.x = distance * (targetOffset.w == 0 ? 1 : targetOffset.w);
	}

	/**
		Load current position from current camera position and target.
		Call if you want to modify manually the camera.
	**/
	public function loadFromCamera( animate = false ) {
		var scene = if( scene == null ) getScene() else scene;
		if( scene == null ) throw "Not in scene";
		targetOffset.load(scene.camera.target);
		targetOffset.w = scene.camera.fovY;

		var pos = scene.camera.pos.sub(scene.camera.target);
		var r = pos.length();
		targetPos.set(r, Math.atan2(pos.y, pos.x), Math.acos(pos.z / r));
		targetPos.x *= targetOffset.w;

		curOffset.w = scene.camera.fovY;

		if( !animate )
			toTarget();
		else
			syncCamera(); // reset camera to current
	}

	/**
		Initialize to look at the whole scene, based on reported scene bounds.
	**/
	public function initFromScene() {
		var scene = getScene();
		if( scene == null ) throw "Not in scene";