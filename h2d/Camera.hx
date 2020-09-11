
package h2d;

/**
	A 2D camera representation attached to `h2d.Scene`.

	Enables ability to move, scale and rotate the scene viewport.

	Scene supports usage of multiple Camera instances.
	To configure which layers each Camera renders - `Camera.layerVisible` method should be overridden.
	By default, camera does not clip out the contents that are outside camera bounding box, which can be enabled through `Camera.clipViewport`.

	Due to Heaps event handling structure, only one Camera instance can handle the mouse/touch input, and can be set through `h2d.Scene.interactiveCamera` variable.
	Note that during even handing, interactive camera does not check if the Camera itself is visible nor the layers filters as well as `clipViewport` is not applied.
**/
@:access(h2d.RenderContext)
@:access(h2d.Scene)
@:allow(h2d.Scene)
class Camera {

	/**
		X position of the camera in world space based on anchorX.
	**/
	public var x(default, set) : Float;
	/**
		Y position of the camera in world space based on anchorY.
	**/
	public var y(default, set) : Float;

	/**
		Horizontal scale factor of the camera. Scaling applied, using anchored position as pivot.
	**/
	public var scaleX(default, set) : Float;
	/**
		Vertical scale factor of the camera. Scaling applied, using anchored position as pivot.
	**/
	public var scaleY(default, set) : Float;

	/**
		Rotation of the camera in radians. Camera is rotated around anchored position.
	**/
	public var rotation(default, set) : Float;

	/**
		Enables viewport clipping. Allow to restrict rendering area of the camera to the viewport boundaries.

		Does not affect the user input when Camera is set as interactive camera.
	**/
	public var clipViewport : Bool;
	/**
		Horizontal viewport offset of the camera relative to internal scene viewport (see `h2d.Scene.scaleMode`) in scene coordinates. ( default : 0 )  
		Automatically scales on scene resize.
	**/
	public var viewportX(get, set) : Float;
	/**
		Vertical viewport offset of the camera relative to internal scene viewport (see `h2d.Scene.scaleMode`) in scene coordinates. ( default : 0 )  
		Automatically scales on scene resize.
	**/
	public var viewportY(get, set) : Float;
	/**
		Camera viewport width in scene coordinates. ( default : scene.width )  
		Automatically scales on scene resize.
	**/
	public var viewportWidth(get, set) : Float;
	/**
		Camera viewport height in scene coordinates. ( default: scene.height )  
		Automatically scales on scene resize.
	**/
	public var viewportHeight(get, set) : Float;

	/**
		Horizontal anchor position inside viewport boundaries used for positioning and resize compensation. ( default : 0 )  
		Value is a percentile (0..1) from left viewport edge to right viewport edge with 0.5 being center.