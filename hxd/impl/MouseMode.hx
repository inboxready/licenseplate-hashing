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
	
	@see 