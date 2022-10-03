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
			flow.debug = true;
			flow.verticalAlign = vAlign;
			flow.horizontalAlign = hAlign;
			flow.horizontalSpacing = 15;
			flow.verticalSpacing = 15;
			flow.padding = 10;
			flow.minHeight = Math.ceil(.5 * size);
			flow.minWidth = size;

			flow.backgroundTile = Tile.fromColor(0x888888);

			var tf = new h2d.Text(font, flow);
			tf.textColor = 0x000000;
			tf.textAlign = Align.Left;
			tf.text = text;

			return flow;
		}

		function screen0() : Void {
			var title = createTitle("0°) 9 flows with text inline");
			var yoffset = title.getBounds().height + spaceY;
			var xoffset = spaceX;

			var flow;

			flow = createFlowSimple(s2d, xoffset, yoffset);

			createFlow(flow, 1, "TopLeft", FlowAlign.Top, FlowAlign.Left);
			createFlow(flow, 2, "TopMiddle", FlowAlign.Top, FlowAlign.Middle);
			createFlow(flow, 3, "TopRight", FlowAlign.Top, FlowAlign.Right);

			createFlow(flow, 4, "CentLeft", FlowAlign.Middle, FlowAlign.Left);
			createFlow(flow, 5, "CentMiddle", FlowAlign.Middle, FlowAlign.Middle);
			createFlow(flow, 6, "CentRight", FlowAlign.Middle, FlowAlign.Right);

			createFlow(flow, 7, "BotLeft", FlowAlign.Bottom, FlowAlign.Left);
			createFlow(flow, 8, "BotMiddle", FlowAlign.Bottom, FlowAlign.Middle);
			createFlow(flow, 9, "BotRight", FlowAlign.Bottom, FlowAlign.Right);

			currentFlows.push(flow);
		}

		function screen1() : Void {
			var title = createTitle("1°) 3 flows with text inline in 3 flows inline");
			var yoffset = title.getBounds().height + spaceY;
			var xoffset = spaceX;

			var flow;
			var subFlow;

			flow = createFlowSimple(s2d, xoffset, yoffset);

			subFlow = createFlowSimple(flow, 0, 0);
			createFlow(subFlow, 1, "TopLeft", FlowAlign.Top, FlowAlign.Left);
			createFlow(subFlow, 2, "TopMiddle", FlowAlign.Top, FlowAlign.Middle);
			createFlow(subFlow, 3, "TopRight", FlowAlign.Top, FlowAlign.Right);

			subFlow = createFlowSimple(flow, 0, 0);
			createFlow(subFlow, 1, "CentLeft", FlowAlign.Middle, FlowAlign.Left);
			createFlow(subFlow, 2, "CentMiddle", FlowAlign.Middle, FlowAlign.Middle);
			createFlow(subFlow, 3, "CentRight", FlowAlign.Middle, FlowAlign.Right);

			subFlow = createFlowSimple(flow, 0, 0);
			createFlow(subFlow, 1, "BotLeft", FlowAlign.Bottom, FlowAlign.Left);
			createFlow(subFlow, 2, "BotMiddle", FlowAlign.Bottom, FlowAlign.Middle);
			createFlow(subFlow, 3, "BotRight", FlowAlign.Bottom, FlowAlign.Right);

			currentFlows.push(flow);
		}

		function screen2() : Void {
			var title = createTitle("2°) 1 flow with text in 1 flow in 1 flow : all alignments");
			var yoffset = title.getBounds().height + spaceY;
			var xoffset = spaceX;

			var flow = createFlowSimple(s2d, xoffset, yoffset);
			flow.minHeight = 200;
			flow.minWidth = 400;
			flow.verticalAlign = FlowAlign.Top;
			flow.horizontalAlign = FlowAlign.Left;
			flow.layout = Vertical;

			var subFlow = createFlowSimple(flow, 0, 0);
			subFlow.minHeight = 100;
			subFlow.minWidth = 200;
			subFlow.verticalAlign = FlowAlign.Top;
			subFlow.horizontalAlign = FlowAlign.Left;
			movingFlow = createFlow(subFlow, 1, "Text", FlowAlign.Top, FlowAlign.Left);

			currentFlows.push(flow);
		}

		function screen3() : Void {
			var title = createTitle("3°) 3 flows with text inline inside 3 flows in column");
			var yoffset = title.getBounds().height + spaceY;
			var xoffset = spaceX;

			var flow;
			var subFlow;

			flow = createFlowSimple(s2d, xoffset, yoffset);
			flow.layout = Vertical;

			subFlow = createFlowSimple(flow, 0, 0);
			createFlow(subFlow, 1, "TopLeft", FlowAlign.Top, FlowAlign.Left);
			createFlow(subFlow, 2, "TopMiddle", FlowAlign.Top, FlowAlign.Middle);
			createFlow(subFlow, 3, "TopRight", FlowAlign.Top, FlowAlign.Right);

			subFlow = createFlowSimple(flow, 0, 0);
			createFlow(subFlow, 4, "CentLeft", FlowAlign.Middle, FlowAlign.Left);
			createFlow(subFlow, 5, "CentMiddle", FlowAlign.Middle, FlowAlign.Middle);
			createFlow(subFlow, 6, "CentRight", FlowAlign.Middle, FlowAlign.Right);

			subFlow = createFlowSimple(flow, 0, 0);
			createFlow(subFlow, 7, "BotLeft", FlowAlign.Bottom, FlowAlign.Left);
			createFlow(subFlow, 8, "BotMiddle", FlowAlign.Bottom, FlowAlign.Middle);
			createFlow(subFlow, 9, "BotRight", FlowAlign.Bottom, FlowAlign.Right);

			currentFlows.push(flow);
		}

		function screen4() : Void {
			var title = createTitle("4°) Reversing");
			var yoffset = title.getBounds().height + spaceY;
			var xoffset = spaceX;

			var flow;

			function generateFlowsWithThreeFlo