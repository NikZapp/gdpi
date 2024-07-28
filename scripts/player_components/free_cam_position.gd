extends Node

@onready var player : CharacterBody3D = get_parent()
@onready var camera = get_node("../Camera")

var speed_exponent = 1
var speed_exponent_change_speed = 1
var speed = 20

func _ready():
	pass

func _physics_process(delta: float) -> void:
	var speed_change = 0
	if !player.normal_movement:
		var direction = Vector3.ZERO
		direction.z = int(Input.is_action_pressed("move_backward")) - int(Input.is_action_pressed("move_forward"))
		direction.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
		direction.y = int(Input.is_action_pressed("move_up")) - int(Input.is_action_pressed("move_down"))
		
		player.velocity = camera.transform.basis * direction * pow(speed, speed_exponent)
		player.move_and_slide()
		
		speed_change = int(Input.is_action_pressed("speed_increase")) - int(Input.is_action_pressed("speed_decrease"))
		speed_exponent += speed_exponent_change_speed * speed_change * delta
		
	if Input.is_action_pressed("align_position"):
		var k = 1.0 - pow(0.01, delta)
		player.position = lerp(player.position, round(player.position), k)
	
	if player.is_debug_module_enabled("freecam_speed"):
		var debug_text
		debug_text = "Speed Exponent:" + str(speed_exponent) + "\n"
		debug_text += "Speed:" + str(pow(speed, speed_exponent)) + "\n"
		match speed_change:
			1:
				debug_text += "Increasing"
			-1:
				debug_text += "Decreasing"
			0:
				debug_text += ""
		player.set_debug_module_text("freecam_speed", debug_text)
