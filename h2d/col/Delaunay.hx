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
	public var p3:P