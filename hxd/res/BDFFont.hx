
package hxd.res;

using StringTools;

/**
 * Intermediate representation of a glyph. Only used while
 * parsing a BDF font file.
 */
 class BDFFontChar {
	public var code : Int;
	public var x : Int;
	public var y : Int;
	public var width : Int;
	public var height : Int;
	public var xoffset : Int;
	public var yoffset : Int;
	public var stride : Int;
	public var bits : Array<Int>;

	public function new( code, width, height, xoffset, yoffset, stride ) {
		this.code = code;
		this.width = width;
		this.height = height;
		this.xoffset = xoffset;
		this.yoffset = yoffset;
		this.stride = stride;
		this.bits = new Array();
	}

	static public function sortOnHeight( a : BDFFontChar, b : BDFFontChar ) {
		return b.height - a.height; // Largest first
	}
}

/**
 * Parse BDF font format to h2d.Font
 */
class BDFFont extends Resource {

	static inline var BitmapPad : Float = 0.1;
	static inline var BitmapMaxWidth : Int = 1024;
	static inline var ClearColor : Int = 0x000000FF;
	static inline var PixelColor : Int = 0x00FFFFFF;

	var font : h2d.Font;
	var bitsPerPixel : Int = 1;
	var ascent : Int = -1;
	var descent : Int = -1;
	var fbbHeight : Int = -1;
	var glyphData : Array<BDFFontChar>;

	/**
	 * Convert BDF resource to a h2d.Font instance
	 * @return h2d.Font The font
	 */
	@:access(h2d.Font)
	public function toFont() : h2d.Font {
		if ( font != null ) return font;

		// File starts with STARTFONT
		var text = entry.getText();
		if( !StringTools.startsWith(text,"STARTFONT") )
			throw 'File does not appear to be a BDF file. Expecting STARTFONT';

		// Init empty font
		font = new h2d.Font( null, 0 );

		// Break file into lines
		var lines = text.split("\n");
		var linenum = 0;

		// Parse the header
		linenum = parseFontHeader( lines, linenum );
		// Parse the glyphs
		linenum = parseGlyphs( lines, linenum );
		// Generate glyphs and bitmap
		generateGlyphs();

		// Return the generated font
		return font;
	}

	/**
	 * Extract what we can from the font header. Unlike other font formats supported by heaps, some
	 * of the values need to be infered from what is given (e.g. line height is not specificed directly,
	 * nor is baseline).
	 * @param lines		The remaining lines in the file
	 * @param linenum	The current line number
	 * @return Int		The final line number after processing header
	 */
	@:access(h2d.Font)
	function parseFontHeader( lines : Array<String>, linenum : Int ) : Int {
		var line : String;
		var prop : String;
		var args : Array<String>;

		// Iterate lines
		while ( lines.length > 0 ) {
			linenum++;

			line = lines.shift();
			args = line.trim().split(" ");
			if ( args.length == 0 ) continue;
			prop = args.shift().trim();

			switch ( prop ) {
				case 'FAMILY_NAME':
					font.name = extractStr( args );
				case 'SIZE':
					font.size = font.initSize = extractInt( args[0] );
				case 'BITS_PER_PIXEL':
					this.bitsPerPixel = extractInt( args[0] );
					if ( [1,2,4,8].indexOf( bitsPerPixel ) != -1 ) throw 'BITS_PER_PIXEL of $bitsPerPixel not supported, at line $linenum';
				case 'FONTBOUNDINGBOX':
					this.fbbHeight = extractInt( args[1] );
				case 'FONT_ASCENT':
					this.ascent = extractInt( args[0] );
				case 'FONT_DESCENT':
					this.descent = extractInt( args[0] );
				// Once we find STARTCHAR we know that the header is done. Stop processing lines and continue.
				case 'STARTCHAR':
					break;
			}
		}
		// Check we have everything we need
		if ( font.initSize == 0 ) throw 'SIZE not found or is 0';

		// Return linenum we are up to
		return linenum;
	}

	/**
	 * Extract glyph information from the file.
	 * @param lines		The remaining lines in the file
	 * @param linenum	The current line number
	 * @return Int		The final line number after processing header
	 */
	function parseGlyphs( lines : Array<String>, linenum : Int ) : Int {
		var line : String;
		var prop : String;
		var args : Array<String>;

		this.glyphData = new Array(); // Destroyed after generating bitmap

		var processingGlyphHeader : Bool = true;
		var encoding : Int = -1;
		var stride : Int = -1;
		var bbxFound : Bool = false;
		var bbxWidth : Int = 0;
		var bbxHeight : Int = 0;
		var bbxXOffset : Int = 0;