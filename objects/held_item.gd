extends Node3D

@onready var label = $Label3D
func set_item(id : int, aux : int = 0):
	if id == 0 and aux == 0:
		label.text = ""
	else:
		label.text = str(id) + ":" + str(aux)
