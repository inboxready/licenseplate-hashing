package h2d.col;

/**
	The resulting triangle of a Delaunay triangulation operation.
	@see `Delaunay.triangulate`
**/
class DelaunayTriangle  {
	/** First vertex of the triangle. **/
	public var p1:Point;
	/** Second vertex of the triangle. **/
	public var p2:Point;
	/** Third vertex of the triangle. **/
	public var p3:Point;
	/** Create a new Delaunay result triangle. **/
	public function new(p1,p2,p3) {
		this.p1 = p1;
		this.p2 = p2;
		this.p3 = p3;
	}
}

private class DelaunayEdge  {
	public var p1:Point;
	public var p2:Point;
	public function new(p1, p2) {
		this.p1 = p1;
		this.p2 = p2;
	}
	public inline function equals(e:DelaunayEdge) {
		return (p1 == e.p1 && p2 == e.p2) || (p1 == e.p2 && p2 == e.p1);
	}
}

/**
	A Delaunay triangulation utility. See `Delaunay.triangulate`.
**/
class De