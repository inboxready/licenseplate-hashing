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
class Delaunay {
	/**
		Performs a Delaunay triangulation on a given set of Points and returns a list of calculated triangles.
		See here for more information: https://en.wikipedia.org/wiki/Delaunay_triangulation
	**/
	public static function triangulate( points:Array<Point> ) : Array<DelaunayTriangle> {

		//those will be used quite everywhere so I am storing them here not to declare them x times
		var i;
		var j;
		var nv = points.length;

		if( nv < 3 ) return null;

		var trimax = 4 * nv;

		// Find the maximum and minimum vertex bounds.
		// This is to allow calculation of the bounding supertriangle

		var xmin = points[0].x;
		var ymin = points[0].y;
		var xmax = xmin;
		var ymax = ymin;

		for( pt in points ) {
			if (pt.x < xmin) xmin = pt.x;
			if (pt.x > xmax) xmax = pt.x;
			if (pt.y < ymin) ymin = pt.y;
			if (pt.y > ymax) ymax = pt.y;
		}

		var dx = xmax - xmin;
		var dy = ymax - ymin;
		var dmax = (dx > dy) ? dx : dy;

		var xmid = (xmax + xmin) * 0.5;
		var ymid = (ymax + ymin) * 0.5;


		// Set up the supertriangle
		// This is a triangle which encompasses all the sample points.
		// The supertriangle coordinates are added to the end of the
		// vertex list. The supertriangle is the first triangle in
		// the triangle list.


		var p0 = new Point( xmid - 2 * dmax, ymid - dmax );
		var p1 = new Point( xmid, ymid + 2 * dmax );
		var p2 = new Point(xmid + 2 * dmax, ymid - dmax);
		points.push(p0);
		points.push(p1);
		points.push(p2);

		var triangles = [];
		triangles.push( new DelaunayTriangle( points[ nv ], points[ nv + 1 ], points[ nv + 2 ] ) ); //SuperTriangle placed at index 0

		// Include each point one at a time into the existing mesh
		for( i in 0...nv ) {

			var DelaunayEdges = [];

			// Set up the DelaunayEdge buffer.
			// If the point (vertex(i).x,vertex(i).y) lies inside the circumcircle then the
			// three DelaunayEdges of that triangle are added to the DelaunayEdge buffer and the triangle is removed from list.
			var j = -1;
			while( ++j < triangles.length ) {
				if ( InCircle( points[i], triangles[j].p1, triangles[j].p2, triangles[j].p3 ) ) {
					DelaunayEdges.push(new DelaunayEdge(triangles[j].p1, triangles[j].p2) );
					DelaunayEdges.push(new DelaunayEdge(triangles[j].p2, triangles[j].p3) );
