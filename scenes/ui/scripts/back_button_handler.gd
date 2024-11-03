extends Control

func _on_button_back_pressed():
	if get_parent().has_method("_on_button_back_pressed"):
		get_parent()._on_button_back_pressed()
