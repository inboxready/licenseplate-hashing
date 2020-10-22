package h2d.filter;
import hxd.Math;

/**
	Adds a soft shadow to the filtered Object.
**/
class DropShadow extends Glow {

	/**
		The offset distance of the shadow in the direction of `DropShadow.angle`.
	**/
	public var distance : Float;
	/**
		The shadow offset direction angle.
	**/
	public var angle : Float;
	var alphaPass = new h3d.mat.Pass("");

	/**
		Create a new Shadow filter.
		@param distance The offset of the shadow in the `angle` direction.
		@param angle Shadow offset direction angle.
		@param color The color of the shadow.
		@param alpha Transparency value of the shadow.
		@param radius The shadow glow distance in pixels.
		@param gai