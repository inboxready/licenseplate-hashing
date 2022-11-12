
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
		for( i in 0...pointLightColors.length ) {
			var l = new PointLight( s3d );
			l.enableSpecular = true;
			l.color.setColor( pointLightColors[i] );
			pointLights.push( l );
			new PointLightHelper( l );
		}

		new CameraController(s3d).loadFromCamera();
	}

	override function update( dt : Float ) {

		time += dt;

		cube.rotate( 0.01, 0.02, 0.03 );

		pointLights[0].x = Math.sin( time ) * 3;
		pointLights[1].y = Math.sin( time ) * 3;
		pointLights[2].z = Math.sin( time ) * 3;
	}

	static function main() {
		Res.initEmbed();
		new Helpers();
	}
}

class AxesHelper extends h3d.scene.Graphics {

	public function new( ?parent : h3d.scene.Object, size = 2.0, colorX = 0xEB304D, colorY = 0x7FC309, colorZ = 0x288DF9, lineWidth = 2.0 ) {

		super( parent );

		material.props = h3d.mat.MaterialSetup.current.getDefaults( "ui" );

		lineShader.width = lineWidth;

		set