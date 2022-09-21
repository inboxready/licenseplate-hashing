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
			flow.verticalSpacing 