extends Node

@onready var player = get_parent()

func _process(_delta):
	var text = "FPS: " + str(Engine.get_frames_per_second())
	player.set_debug_module_text("performance_fps", text)
