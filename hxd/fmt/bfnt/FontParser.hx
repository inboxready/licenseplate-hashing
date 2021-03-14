
package hxd.fmt.bfnt;

#if (haxe_ver < 4)
import haxe.xml.Fast in Access;
#else
import haxe.xml.Access;
#end

class FontParser {

	@:access(h2d.Font)
	public static function parse(bytes : haxe.io.Bytes, path : String, resolveTile: String -> h2d.Tile ) : h2d.Font {

		// TODO: Support multiple textures per font.

		var tile : h2d.Tile = null;
		var font : h2d.Font = new h2d.Font(null, 0);
		var glyphs = font.glyphs;

		inline function resolveTileSameName() {
			font.tilePath = new haxe.io.Path(path).file + ".png";
			tile = resolveTile(haxe.io.Path.withExtension(path, "png"));
		}

		inline function resolveTileWithFallback( tilePath : String ) {
			try {
				font.tilePath = tilePath;
				tile = resolveTile(haxe.io.Path.join([haxe.io.Path.directory(path), tilePath]));
			} catch ( e : Dynamic ) {
				trace('Warning: Could not find referenced font texture at "${tilePath}", trying to resolve same name as fnt!');
				resolveTileSameName();
			}
		}

		// Supported formats:
		// Littera formats: XML and Text
		// http://kvazars.com/littera/
		// BMFont: Binary(v3)/Text/XML
		// http://www.angelcode.com/products/bmfont/
		// FontBuilder: Divo/BMF
		// https://github.com/andryblack/fontbuilder/downloads
		// Hiero from LibGDX is BMF Text format and supported as well.
		// https://github.com/libgdx/libgdx

		font.baseLine = 0;

		switch( bytes.getInt32(0) ) {
		case 0x544E4642: // Internal BFNT
			return hxd.fmt.bfnt.Reader.parse(bytes, function( tp : String ) { resolveTileWithFallback(tp); return tile; });

		case 0x6D783F3C, // <?xml : XML file
				 0x6E6F663C: // <font>
			var xml = Xml.parse(bytes.toString());
			var xml = new Access(xml.firstElement());
			if (xml.hasNode.info) {
				// support for Littera XML format (starts with <font>) and BMFont XML format (<?xml).
				font.name = xml.node.info.att.face;