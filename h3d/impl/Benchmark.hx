package h3d.impl;

private class QueryObject {

	var driver : h3d.impl.Driver;

	public var q : h3d.impl.Driver.Query;
	public var value : Float;
	public var name : String;
	public var drawCalls : Int;
	public var next : QueryObject;

	public function new() {
		driver = h3d.Engine.getCurrent().driver;
		q = driver.allocQuery(TimeStamp);
	}

	public function sync() {
		value = driver.queryResult(q);
	}

	public function isAvailable() {
		return driver.queryResultAvailable(q);
	}

	public function dispose() {
		driver.deleteQuery(q);
		q = null;
	}

}

private class StatsObject {
	public var name : String;
	public var time : Float;
	public var drawCalls : Int;
	public var next : StatsObject;
	public var xPos : Int;
	public var xSize : Int;
	public function new() {
	}
}

class Benchmark extends h2d.Graphics {

	var cachedStats : StatsObject;
	var currentStats : StatsObject;
	var cachedQueries : QueryObject;
	var currentFrame : QueryObject;
	var waitFrames : Array<QueryObject>;
	var engine : h3d.Engine;
	var stats : StatsObject;
	var labels : Array<h2d.Text>;
	var interact : h2d.Interactive;

	public var estimateWait = false;
	public var enable(default,set) : Bool;

	public var width : Null<Int>;
	public var height = 16;
	public var textColor = 0;
	public var colors = new Array<Int>();
	public var font : h2d.Font;

	public var recalTime = 1e9;
	public var smoothTime = 0.95;

	public var measureCpu = false;

	var tip : h2d.Text;
	var tipCurrent : StatsObject;
	var tipCurName : String;
	var curWidth : Int;
	var prevFrame : Float;
	var frameTime : Float;

	public function new(?parent) {
		super(parent);
		waitFrames = [];
		labels = [];
		engine = h3d.Engine.getCurrent();
		interact = new h2d.Interactive(0,0,this);
		interact.onMove = onMove;
		interact.cursor = Default;
		interact.onOut = function(_) {
			if( tip == null ) return;
			tip.parent.remove();
			tip = null;
			tipCurrent = null;
		}
		enable = engine.driver.hasFeature(Queries);
	}

	function set_enable(e) {
		if( !e )
			cleanup();
		return enable = e;
	}

	function cleanup() {
		while( waitFrames.length > 0 ) {
			var w = waitFrames.pop();
			while( w != null ) {
				w.dispose();
				w = w.next;
			}
		}
		while( cachedQueries != null ) {
			cachedQueries.dispose();
			cachedQueries = cachedQueries.next;
		}
		while( currentFrame != null ) {
			currentFrame.dispose();
			currentFrame = currentFrame.next;
		}
	}

	override function clear() {
		super.clear();
		if( labels != null ) {
			for( t in labels ) t.remove();
			labels = [];
		}
		if( interact != null ) interact.width = interact.height = 0;
	}

	override function onRemove() {
		super.onRemove();
		cleanup();
	}

	function onMove(e:hxd.Event) {
		var s = currentStats;
		while( s != null ) {
			if( e.relX >= s.xPos && e.relX <= s.xPos + s.xSize )
				break;
			s = s.next;
		}
		if( tip == null ) {
			var fl = new h2d.Flow(this);
			fl.y = -23;
			fl.backgroundTile = h2d.Tile.fromColor(0,1,1,0.8);
			fl.padding = 5;
			tip = new h2d.Text(font, fl);
			tip.dropShadow = { dx : 0, dy : 1, color : 0, alpha : 1 };
		}
		tipCurrent = s;
		tipCurName = s == null ? null : s.name;
		syncTip(s);
	}

	function syncTip(s:StatsObject) {
		if( s == null )
			tip.text = "total "+engine.drawCalls+" draws "+hxd.Math.fmt(engine.drawTriangles/1000000)+" Mtri";
		else
			tip.text = s.name+"( " + Std.int(s.time / 1e6) + "." + StringTools.lpad(""+(Std.int(s.time/1e4)%100),"0",2) + " ms " + s.drawCalls + " draws )";
		var tw = tip.textWidth + 10;
		var tx = s == null ? curWidth : s.xPos + ((s.xSize - tw) * .5);
		if( tx + tw > curWidth ) tx = curWidth - tw;
		if( tx < 0 ) tx = 0;
		if( hxd.Math.abs(tip.parent.x - tx) > 5 ) tip.parent.x = Std.int(tx);
	}

	public function begin() {

		if( !enable ) return;

		var t0 = haxe.Timer.stamp();
		var ft = (t0 - prevFrame) * 1e9;
		if( hx