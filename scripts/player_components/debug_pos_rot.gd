extends Node

@onready var player = get_parent()
@onready var camera = get_node("../Camera")

func _process(_delta):
	if player.is_debug_module_enabled("pos_rot_display"):
		var text = "O: " + str(player.transform.origin) + "\n"
		text += " x: " + str(camera.transform.basis.x) + "\n"
		text += " y: " + str(camera.transform.basis.y) + "\n"
		text += " z: " + str(camera.transform.basis.z)
		player.set_debug_module_text("pos_rot_display", text)
