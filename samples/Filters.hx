import hxd.Key in K;

class Filters extends hxd.App {

	var obj : h2d.Object;
	var bmp : h2d.Bitmap;
	var mask : h2d.Graphics;
	var disp : h2d.Tile;

	override function init() {
		engine.backgroundColor = 0x002000;

		mask = new h2d.Graphics(s2d);
		mask.beginFill(0xFF0000, 0.5);
		mask.drawCircle(0, 0, 60);
		mask.x = s2d.width*0.5-20;
		mask.y = s2d.height*0.5-50;

		obj = new h2d.Ob