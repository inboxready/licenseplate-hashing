
package hxd.earcut;

class EarNode {
	public var next : EarNode;
	public var prev : EarNode;
	public var nextZ : EarNode;
	public var prevZ : EarNode;
	public var allocNext : EarNode;
	public var x : Float;
	public var y : Float;
	public var i : Int;
	public var z : Int;
	public var steiner : Bool;
	public function new() {
	}
}

/**
	Ported from https://github.com/mapbox/earcut by @ncannasse
**/
class Earcut {

	var triangles : Array<Int>;
	var cache : EarNode;
	var allocated : EarNode;
	var minX : Float;
	var minY : Float;
	var size : Float;
	var hasSize : Bool;

	public function new() {
	}

	@:generic public function triangulate < T: { x:Float, y:Float } > ( points : Array<T>, ?holes : Array<Int> ) : Array<Int> {

		var hasHoles = holes != null && holes.length > 0;
        var outerLen = hasHoles ? holes[0] : points.length;
		if( outerLen < 3 ) return [];

		var root = setLinkedList(points, 0, outerLen, true);
		//eliminate holes
		if(holes != null)
			root = eliminateHoles(points, holes, root);

		return triangulateNode(root, points.length > 80);
	}

	public function triangulateNode( root : EarNode, useZOrder ) {
		triangles = [];
		root = filterPoints(root);
		if( useZOrder && root != null ) {
			var maxX, maxY;
			minX = maxX = root.x;
			minY = maxY = root.y;
			var p = root.next;
			while( p != root ) {
				var x = p.x;
				var y = p.y;
				if (x < minX) minX = x;
				if (y < minY) minY = y;
				if (x > maxX) maxX = x;
				if (y > maxY) maxY = y;
				p = p.next;
			}
			// minX, minY and size are later used to transform coords into integers for z-order calculation
			size = Math.max(maxX - minX, maxY - minY);
			hasSize = true;
		} else
			hasSize = false;
		earcutLinked(root);
		var result = triangles;
		triangles = null;

		// recycle allocated into cache
		var n = allocated;
		if( cache != null ) {
			while( n != cache )
				n = n.allocNext;
			n = n.allocNext;
		}
		while( n != null ) {
			n.next = cache;
			cache = n;
			n = n.allocNext;
		}

		return result;
	}

	@:generic function setLinkedList < T: { x:Float, y:Float } > (points : Array<T>, start : Int, end : Int, clockwise : Bool) {

		// check polygon winding
		var sum = 0.;
		var j = end - 1;
		for (i in start...end) {
			sum += (points[j].x - points[i].x) * (points[i].y + points[j].y);
			j = i;
		}

		// link points into circular doubly-linked list in the specified winding order
		var node = allocNode(-1, 0, 0, null);
		var first = node;
		if (clockwise == (sum > 0)) {
			for (i in start...end) {
				var p = points[i];
				node = allocNode(i, p.x, p.y, node);
			}
		}
		else {
			var i = end - 1;
			while(i >= start) {
				var p = points[i];
				node = allocNode(i, p.x, p.y, node);
				i--;
			}
		}

		node.next = first.next;
		node.next.prev = node;
		return node;
	}

	// link every hole into the outer loop, producing a single-ring polygon without holes
	@:generic function eliminateHoles < T: { x:Float, y:Float } > (points : Array<T>, holes : Array<Int>, root : EarNode) {
		var queue = [];

		for(i in 0...holes.length) {
			var s = holes[i];
			var e = i == holes.length - 1 ? points.length : holes[i + 1];
			var node = setLinkedList(points, s, e, false);
			if (node == node.next) node.steiner = true;
			queue.push(getLeftmost(node));
		}

		queue.sort(compareX);

		// process holes from left to right
		for( q in queue) {
			eliminateHole(q, root);
			root = filterPoints(root, root.next);
		}

		return root;
	}

	// find a bridge between vertices that connects hole with an outer ring and and link it
	function eliminateHole(hole, root) {
		root = findHoleBridge(hole, root);
		if (root != null) {
			var b = splitPolygon(root, hole);
			filterPoints(b, b.next);
		}
	}

	// David Eberly's algorithm for finding a bridge between hole and outer polygon
	function findHoleBridge(hole : EarNode, root : EarNode) {
		var p = root;
		var hx = hole.x;
		var hy = hole.y;
		var qx = Math.NEGATIVE_INFINITY;
		var m = null;

		// find a segment intersected by a ray from the hole's leftmost point to the left;
		// segment's endpoint with lesser x will be potential connection point
		do {
			if (hy <= p.y && hy >= p.next.y) {
				var x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y);
				if (x <= hx && x > qx) {
					qx = x;
					m = p.x < p.next.x ? p : p.next;
				}
			}
			p = p.next;
		} while (p != root);

		if (m == null) return null;

		// look for points inside the triangle of hole point, segment intersection and endpoint;
		// if there are no points found, we have a valid connection;
		// otherwise choose the point of the minimum angle with the ray as connection point
		var stop = m;
		var tanMin = Math.POSITIVE_INFINITY;
		var tan;

		p = m.next;
		while (p != stop) {
			if (hx >= p.x && p.x >= m.x && pointInTriangle(hy < m.y ? hx : qx, hy, m.x, m.y, hy < m.y ? qx : hx, hy, p.x, p.y)) {
				tan = Math.abs(hy - p.y) / (hx - p.x); // tangential
				if ((tan < tanMin || (tan == tanMin && p.x > m.x)) && locallyInside(p, hole)) {
					m = p;
					tanMin = tan;
				}
			}
			p = p.next;
		}

		return m;
	}

	// find the leftmost node of a polygon ring
	function getLeftmost(node : EarNode) {
		var p = node, leftmost = node;
		do {
			if (p.x < leftmost.x) leftmost = p;
			p = p.next;
		} while (p != node);

		return leftmost;
	}


	inline function compareX(a : EarNode, b : EarNode) {
		return a.x - b.x > 0 ? 1 : -1;
	}

	inline function equals(p1:EarNode, p2:EarNode) {
		return p1.x == p2.x && p1.y == p2.y;
	}