import h2d.Tile;
import hxd.Key;
import h2d.Flow;
import h2d.Object;
import h2d.Text.Align;

class Flows extends hxd.App {

	// for animation
	var hAligns = [FlowAlign.Left, FlowAlign.Middle, FlowAlign.Right];
	var vAligns = [FlowAlign.Top, FlowAlign.Middle, FlowAlign.Bottom];

	var movingFlow : Flow;
	var reversedFlow : Array<Flow> = [];
	var vAlignChildFlow : Array<Flow> = [];
	var hAlignChildFlow : Array<Flow> = [];

	// for screens
	var idxFctDisplayed = 9; // also the first screen displayed
	var fctGenerationScreen : Array<Void -> Void> = []; // list of functions generating screen
	var currentFlows : Array<Flow> = []; // removed when switching screen

	var event = new hxd.WaitEvent();

	override function init() {

		var font = hxd.res.DefaultFont.get();

		var colors = [0xff0000, 0x00ffff, 0xffffff, 0x00ff00, 0x0080ff, 0xff8000, 0x7000ff, 0xff00ff, 0x0000ff, 0xff007f, 0x808080, 0xe0e0e0];

		var spaceX = 10.0;
		var spaceY = 10.0;

		// Flows
		function createText(parent:Object, color : Int, text : String) {
			var flow = new Flow(parent);
			flow.backgroundTile = Tile.fromColor(colors[color]);
			flow.padding = 5;
			flow.horizontalSpacing = 15;
			flow.verticalSpacing = 15;

			var tf = new h2d.Text(font, flow);
			tf.textColor = 0x000000;
			tf.textAlign = Align.Left;
			tf.text = text;

			currentFlows.push(flow);
			return flow;
		}

		function createTitle(text : String) {
			return createText(s2d, 11, text + " - Use LEFT and RIGHT ARROWS to switch screen");
		}

		function createFlowSimple(parent:Object, x : Float, y : Float, size = 75) {
			var flow = new Flow(parent);
			flow.debug = true;
			flow.horizontalSpacing = 15;
			flow.verticalSpacing = 15;
			flow.padding = 10;
			flow.minHeight = Math.ceil(.5 * size);
			flow.minWidth = size;
			flow.backgroundTile = Tile.fromColor(0xaaaaaa);

			flow.x = x;
			flow.y = y;

			return flow;
		}

		function createFlow(parent:Object, color : Int, text : String, vAlign:FlowAlign, hAlign:FlowAlign, size = 100) {
			var flow = new Flow(parent);
			flow.debug = true;
			flow.horizontalAlign = hAlign;
			flow.verticalAlign = vAlign;
			flow.horizontalSpacing = 15;
			flow.verticalSpacing = 15;
			flow.padding = 5;
			flow.minHeight = Math.ceil(.5 * size);
			flow.minWidth = size;

			flow.backgroundTile = Tile.fromColor(0x888888);

			createText(flow, color, text);

			return flow;
		}

		function createFlowWithText(parent:Object, size : Int, vAlign: FlowAlign, hAlign : FlowAlign, text : String) {
			var flow = new Flow(parent);
			f