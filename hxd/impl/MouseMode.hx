package hxd.impl;

/**
	The mouse movement input handling mode.

	**JS/HTML5 note**:
	> Due to browser limitations, `restorePos` is ignored and always treated as `true`.
	>
	> Additionally, mouse mode will be forcefully changed to `Absolute` when user performs a browser action that exits the mouse capture mode,
	e.g. pressing Escape or switching tabs/windows.
	> Override `Window.onMouseModeChange` event in order to catch such cases.
	>
	> If mouse is not currently captured, but `mouseMode` is set to either `Relative` or `AbsoluteUnbound`,
	mouse movement events are ignored and first click on the canvas is used to capture the mouse and hence discarded.
	
	@see `hxd.Window.mouseMode`
**/
enum MouseMode {
	/**
		Default mouse movement mode. Causes `EMove` events in window coordinates.
	**/
	Absolute;
	/**
		Relative mouse movement mode. In this mode the mouse cursor is hidden and instead of `EMove` event the `callback` is invoked with relative mouse movement.

		During Relative mouse mode the window mouse position is not updated.

		@param callback The callback to which the relative mouse movements are reported.
