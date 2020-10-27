
package h2d.filter;

/**
	The base filter class, you can extend it in order to define your own filters, although ShaderFilter will be the most straightforward way to define simple custom filter.

	Keep in mind that filters use internal Object resolution to render its content, hence scaling of the filtered object would not increase the rendering resolution.
	For example, 20x20px `Bitmap` with `scale = 2` will render onto 20x20 filter texture if filter is attached to it directly,
	but if filter is attached to the parent of that bitmap, filter will render 40x40 texture.
	Another thing to be aware of, is that `Scene.scaleMode` does not affect filter resolution either,
	and upscaling contents with `scaleMode` would not upscale the resolution of filtered content.

	Filters limit their render area dictated by bound object boundaries, `Filter.autoBounds` and `Filter.boundsExtend` variables and `Filter.getBounds` method.
	See their respective docs for details.

	For optimization purposes, rendering boundaries are clipped by scene viewport and nothing will be rendered offscreen.
**/
class Filter {

	/**
		When enabled, rendering bounds of the filter will be expanded by `Filter.boundsExtend` in all directions.
		Otherwise filter should provide custom bounds through `Filter.getBounds` call.
		Default : true.
	**/
	public var autoBounds = true;
	/**
		Rendering texture boundaries extent. Increases the rendering area by twice the `Filter.boundsExtend` value.
		Automatically applied to object bounds when `autoBounds = true` or `Filter.getBounds` is not overridden.
		Does not affect boundaries when `autoBounds = true` and `boundsExtend` is less than 0.
	**/
	public var boundsExtend : Float = 0.;
	/**
		When enabled, some filters will use bilinear filtering on temporary textures.
		Does not affect the majority of filters.
		@see `AbstractMask`
	**/
	public var smooth = false;
	/**
		When filter is disabled, attached object will render as usual.
	**/
	@:isVar public var enable(get,set) = true;

	/**
		Custom rendering resolution scaling of the filter.

		Stacks with additional scaling from `Filter.useResolutionScaling` if enabled.
	**/
	public var resolutionScale(default, set):Float = 1;
	/**
		Use the screen resolution to upscale/downscale the filter rendering resolution.

		Stacks with additional scaling from `Filter.resolutionScale` if enabled.
	**/
	public var useScreenResolution(default, set):Bool = defaultUseScreenResolution;
	/**
		Defines default value for `Filter.useResolutionScaling`.
	**/
	public static var defaultUseScreenResolution:Bool = false;

	function new() {
	}

	function get_enable() return enable;
	function set_enable(v) return enable = v;

	function set_resolutionScale(v) return resolutionScale = v;
	function set_useScreenResolution(v) return useScreenResolution = v;
