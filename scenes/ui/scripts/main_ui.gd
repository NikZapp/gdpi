extends Node

@onready var main_screen = $MainScreen
@onready var server_screen = $ServerScreen

func _on_button_servers_pressed():
	server_screen.visible = true
	main_screen.visible = false

func _on_button_settings_pressed():
	pass # Replace with function body.

func _on_button_quit_pressed():
	get_tree().quit()

func _on_button_back_pressed():
	main_screen.visible = true
	server_screen.visible = false
