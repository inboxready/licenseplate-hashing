import h3d.prim.Cube;
import h3d.prim.Cylinder;
import h3d.prim.Disc;
import h3d.prim.GeoSphere;
import h3d.prim.Grid;
import h3d.prim.Sphere;
import h3d.scene.CameraController;
import h3d.scene.Mesh;
import h3d.Vector;
import hxd.Key;

/**
 * Third person camera controller (top view) with arrow keys mapping
 */
class ThirdPersonCameraController extends CameraController {
	override function onEvent( e : hxd.Event ) {
		super.onEvent(e);

		// Third person camera arrow keys mapping
		if (e.keyCode == Key.UP) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			pan(Math.sin(radian), Math.cos(radian));
		}
		if (e.keyCode == Key.LEFT) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			radian = radian - Math.PI / 2.0;
			pan(Math.sin(radian), Math.cos(radian));
		}
		if (e.keyCode == Key.DOWN) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			radian = radian + Math.PI;
			pan(Math.sin(radian), Math.cos(radian));
		}
		if (e.keyCode == Key.RIGHT) {
			var radian = Math.atan2((curPos.y - target.y), (curPos.x - target.x));
			radian = radian + Math.PI / 2.0;
			pan(Math.sin(radian), Math.cos(radian));
		}
	}
}

class Polygons extends hxd.App {

	var shadow : h3d.pass.DefaultShadowMap;
	var cameraCtrl : h3d.scene.CameraController;

	override function init() {

		// Grid
		var grid = new Grid(64, 64);
		grid.addNormals();
		grid.addUVs();
		var gridMesh = new Mesh(grid, s3d);
		gridMesh.material.color.setColor(0x999999);

		// Cube
		var cube = Cube.defaultUnitCube();
		var cubeMesh = new Mesh(cube, s