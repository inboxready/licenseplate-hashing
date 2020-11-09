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
	