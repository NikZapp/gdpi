extends Node

@onready var player = get_parent()

func _process(_delta):
	if Input.is_action_just_pressed("chat_open"):
		player.open_chat()
	if Input.is_action_just_pressed("chat_close"):
		player.close_chat()
	if Input.is_action_just_pressed("ui_text_submit"):
		player.send_chat()
