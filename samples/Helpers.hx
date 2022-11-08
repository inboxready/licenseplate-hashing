
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

		var prim = new h3d.prim.Cube( 1, 1, 1, true );
		prim.unindex();
		prim.addNormals();
		prim.addUVs();

		cube = new Mesh( prim, s3d );
		cube.setPosition( 0, 0, 2 );
		cube.material.shadows = false;

		new AxesHelper( cube, 1 );

		cast(s3d.lightSystem,h3d.scene.fwd.LightSystem).ambientLight.set( 0.3, 0.3, 0.3 );

		var dirLight = new DirLight( new Vector( 0.5, 0.5, -0.5 ), s3d );
		dirLight.enableSpecular = true;

		var pointLightColors =  [0xEB304D,0x7FC309,0x288DF9];
		for( i in 0.