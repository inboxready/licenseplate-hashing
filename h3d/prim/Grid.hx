package h3d.prim;

class Grid extends Polygon {

	public var width (default, null) : Int;
	public var height (default, null)  : Int;
	public var cellWidth (default, null) : Float;
	public var cellHeight (default, null)  : Float;

	public function new( width : Int, height : Int, cellWidth = 1., cellHeight = 1. ) {
		this.width = width;
		this.height = height;
		this.cellWidth = cellWidth;
		this.cellHeight = cellHeight;

		var idx = new hxd.IndexBuffer();
		for( y in 0