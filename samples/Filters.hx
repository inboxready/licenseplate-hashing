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

		obj = new h2d.Object(s2d);
		obj.x = s2d.width * 0.5;
		obj.y = s2d.height * 0.5;

		bmp = new h2d.Bitmap(hxd.Res.hxlogo.toTile(), obj);
		bmp.colorKey = 0xFFFFFF;

		disp = hxd.Res.normalmap.toTile();
		setFilters(6);

		var help = new h2d.Text(hxd.Res.customFont.toFont(), s2d);
		help.x = help.y = 5;
		help.text = "0:Disable 1:Blur 2:Glow 3:DropShadow 4:Displacement 5:Glow(Knockout) 6:Mix 7:ColorMatrix 8:Mask +/-:Scale";
	}

	override function update(dt:Float) {
		for( i in 0...10 )
			