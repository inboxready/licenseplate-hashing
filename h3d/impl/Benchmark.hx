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
	