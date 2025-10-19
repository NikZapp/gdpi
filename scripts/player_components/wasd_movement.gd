extends Node

@onready var player : CharacterBody3D = get_parent()
@onready var camera = get_node("../Camera")

var speed_exponent = 1
var speed_exponent_change_speed = 1
var speed = 20

func _physics_process(delta: float) -> void:
	if player.normal_movement and len(player.current_menu_path) == 0:
		player.movement.x = Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left")
		player.movement.z = Input.get_action_strength("walk_backwards") - Input.get_action_strength("walk_forwards")
		
		if Input.is_action_just_pressed("jump"):
			player.jump()
		
		player.sneak(Input.is_action_pressed("sneak"))
		if Input.is_action_pressed("sneak"):
			print("sneak")
		player.sprint(Input.is_action_pressed("sprint"))
