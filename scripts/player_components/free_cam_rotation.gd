extends Node

@onready var player : CharacterBody3D = get_parent()
@onready var camera = get_node("../Camera")

var rotation_speed = deg_to_rad(40)

func _process(delta):
	if true: #!player.normal_movement:
		var rotation_direction = Vector3.ZERO
		rotation_direction.z = int(Input.is_action_pressed("turn_counterclockwise")) - int(Input.is_action_pressed("turn_clockwise"))
		rotation_direction.x = int(Input.is_action_pressed("turn_right")) - int(Input.is_action_pressed("turn_left"))
		rotation_direction.y = int(Input.is_action_pressed("turn_up")) - int(Input.is_action_pressed("turn_down"))
		
		if rotation_direction != Vector3.ZERO:
			var cross_vector = Vector3.FORWARD.cross(rotation_direction).normalized()
			if cross_vector == Vector3.ZERO:
				cross_vector = rotation_direction
			camera.rotate_object_local(cross_vector, delta * rotation_direction.length() * rotation_speed)
		
		var speed_change = int(Input.is_action_pressed("speed_increase")) - int(Input.is_action_pressed("speed_decrease"))
		
	if Input.is_action_pressed("align_rotation"):
		var k = 1.0 - pow(0.05, delta)
		camera.transform = Transform3D(
			lerp(camera.basis.x, round(camera.basis.x), k), 
			lerp(camera.basis.y, round(camera.basis.y), k), 
			lerp(camera.basis.z, round(camera.basis.z), k), 
			camera.position).orthonormalized()
