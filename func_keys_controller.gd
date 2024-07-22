extends Node

@onready var player = get_parent()

func cycle_view_debug() -> void:
	match get_viewport().debug_draw:
		Viewport.DEBUG_DRAW_DISABLED:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
		Viewport.DEBUG_DRAW_OVERDRAW:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
		_:
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED

func cycle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("screenshot"):
		var time_str = Time.get_datetime_string_from_system()
		var filename = "screenshot_" + time_str
		player.screenshot(filename)
	if Input.is_action_just_pressed("view_mode_cycle"):
		cycle_view_debug()
	if Input.is_action_just_pressed("fullscreen"):
		cycle_fullscreen()
