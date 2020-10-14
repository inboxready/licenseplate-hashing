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
		@default 255
	**/
	public var redCutoff : Int;
	/**
		The green channel cutoff value in range of -1...255

		Set to 255 to always fail the test.
		@default 255
	**/
	public var greenCutoff : Int;
	/**
		The blue channel cutoff value in range of -1...255

		Set to 255 to always fail the test.
		@default 255
	**/
	public var blueCutoff : Int;

	/**
		The alpha channel cutoff value in range of -1...255

		Set to 255 to always fail the test.
		@default 127
	**/
	public var alphaCutoff : Int;

	/**
		If true, will collide if any channel is above cutoff. Otherwise will collide only if all channels above their cutoff values.
		@default true
	**/
	public var collideOnAny : Bool;

	/**
		Horizontal stretch of pixels to check for collision.
	**/
	public var scaleX : Float = 1;
	/**
		Vertical stretch of pixels to check for collision.
	**/
	public var scaleY : Float = 1;

	/**
		Create new BitmapCollider with specified b