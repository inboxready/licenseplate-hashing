
import hxd.Res;
import h3d.Vector;
import h3d.scene.*;
import h3d.scene.fwd.*;

class Helpers extends hxd.App {

	var time = 0.0;
	var cube : Mesh;
	var pointLights = new Array<PointLight>();

	override function init() {

		s3d.camera.pos.set( 5, 5, 5 );
		s3d.camera.setFovX( 70, s3d.camera.screenRatio );

		new AxesHelper( s3d );
		new GridHelper( s3d, 10, 10 );

		var prim = new h3d.prim.Cube( 1