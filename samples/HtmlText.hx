
import h2d.Drawable;
import h2d.Flow;
import h2d.Font;
import h2d.Graphics;
import h2d.Object;
import h2d.Text.Align;

// Use both text_res and res folders.
//PARAM=-D resourcesPath=../../text_res;../../res
class HtmlTextWidget extends Object
{
	public var align: Align;
	public var textField: h2d.HtmlText;
	public var back: Graphics;

	public function new(parent:h2d.Scene, font: Font, str:String, align:h2d.Text.Align){
		super(parent);
		this.align = align;
		back = new Graphics(this);

		var tf = new h2d.HtmlText(font, this);
		tf.textColor = 0xffffff;
		tf.textAlign = align;
		tf.text = str;
		textField = tf;

		refreshBounds();
	}

	public function refreshBounds() {
		back.clear();

		var bounds = textField.getBounds(this);
		var size = textField.getSize();

		back.beginFill(0x5050ff,  0.5);
		back.drawRect(bounds.x, 0, size.width, size.height);
		back.endFill();

		back.lineStyle(1, 0x50ff50);
		back.drawRect(bounds.x, bounds.y, bounds.width, bounds.height);

		back.lineStyle(1, 0xff5050);
		back.moveTo(bounds.x, 0);
		back.lineTo(bounds.x + textField.textWidth, 0);
		back.moveTo(bounds.x, 0);
		back.lineTo(bounds.x, textField.textHeight);
	}

	public function setMaxWidth(w:Int) {
		textField.maxWidth = w;
		refreshBounds();
	}
}

class HtmlText extends hxd.App {

	var textWidgets:Array<HtmlTextWidget> = [];
	var resizeWidgets: Array<HtmlTextWidget> = [];

	override function init() {

		// Enable global scaling
		// s2d.scale(1.25);

		var font = hxd.res.DefaultFont.get();
		// var font = hxd.Res.customFont.toFont();

		h2d.HtmlText.defaultLoadFont = function( face : String ) : h2d.Font {
			if ( face == 'myFontFace' ) {
				var font = hxd.res.DefaultFont.get().clone();
				font.resizeTo(font.size * 2);
				return font;
			}
			return null;
		}
		h2d.HtmlText.defaultLoadImage = function( src : String ) : h2d.Tile {
			if ( src == "logo" ) {
				var t = hxd.Res.hxlogo.toTile();
				t.scaleToSize(16, 16);
				return t;
			}
			return null;
		}

		var multilineText = "This is a multiline <font color=\"#FF00FF\">text.<br/>Lorem</font> ipsum dolor";
		var singleText = "Hello simple text";

		var xpos = 0;
		var yoffset = 10.0;

		function createWidget(str:String, align:h2d.Text.Align) {
			var w = new HtmlTextWidget(s2d, font, str, align);
			w.x = xpos;
			w.y = yoffset;
			textWidgets.push(w);
			return w;
		}

		// Static single and multiline widgets
		xpos += 450;
		for (a in [Align.Left, Align.Center, Align.Right, Align.MultilineCenter, Align.MultilineRight]) {
			var w = createWidget("", a);
			var label = new h2d.HtmlText(font, w);
			label.text = Std.string(a);
			label.x = 5;
			label.alpha = 0.5;
			yoffset += w.textField.textHeight + 10;
			var w = createWidget(singleText, a);
			yoffset += w.textField.textHeight + 10;
			var w = createWidget(multilineText, a);
			yoffset += w.textField.textHeight + 10;
		}

		// Resized widgets
		xpos += 200;
		yoffset = 10;
		var longText = "Long text long text. Icons like this one <img src='logo'/> are flowed separately, but they should <font color=\"#FF00FF\">stick</font> to the text when they appear <img src='logo'/>before or after<img src='logo'/>. We support different <font face='myFontFace'>font faces</font>";
		for (a in [Align.Left, Align.Center, Align.Right, Align.MultilineCenter, Align.MultilineRight]) {
			var w = createWidget(longText, a);
			w.setMaxWidth(200);
			resizeWidgets.push(w);
			yoffset += 160;
		}

		// Flows
		function createText(parent:Object, str : String, align:Align) {
			var tf = new h2d.HtmlText(font, parent);
			tf.textColor = 0xffffff;
			tf.textAlign = align;
			tf.text = str;
			tf.maxWidth = 150;
			return tf;
		}