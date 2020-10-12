package h2d.col;

/**
	An `hxd.Pixels`-based collider. Checks for pixel color value under point to be above the cutoff value.

	Note that it checks as `channel > cutoff`, not `channel >= cutoff`, hence cutoff value of 255 would never pass the test.
**/
class PixelsCollider implements Collider {

	/**
		The source pixel data which is tested against.
	**/
	public var pixels : hxd.Pixels;

	/**
		The red channel cutoff value in range of -1...255

		Set to 255 to always fail the test.
		@d