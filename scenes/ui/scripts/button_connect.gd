extends Button

@onready var line_edit_username: LineEdit = $"../GridContainer/LineEditUsername"
@onready var line_edit_ip: LineEdit = $"../GridContainer/LineEditIP"
@onready var line_edit_port: LineEdit = $"../GridContainer/LineEditPort"


func _on_pressed() -> void:
	Global.username = line_edit_username.text
	Global.ip = line_edit_ip.text
	Global.port = int(line_edit_port.text)
	
	if Global.username == "":
		Global.username = "GodotPi"
	if Global.ip == "":
		Global.ip = "localhost"
	if Global.port == 0:
		Global.port = 19132
	
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")
