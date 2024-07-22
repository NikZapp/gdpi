extends Node

@onready var rotation_object = get_node("../Camera")

var rotation_speed = deg_to_rad(40)

func _process(delta):
	var rotation_direction = Vector3.ZERO
	rotation_direction.z = int(Input.is_action_pressed("turn_counterclockwise")) - int(Input.is_action_pressed("turn_clockwise"))
	rotation_direction.x = int(Input.is_action_pressed("turn_right")) - int(Input.is_action_pressed("turn_left"))
	rotation_direction.y = int(Input.is_action_pressed("turn_up")) - int(Input.is_action_pressed("turn_down"))
	
	if rotation_direction != Vector3.ZERO:
		var cross_vector = Vector3.FORWARD.cross(rotation_direction).normalized()
		if cross_vector == Vector3.ZERO:
			cross_vector = rotation_direction
		rotation_object.rotate_object_local(cross_vector, delta * rotation_direction.length() * rotation_speed)
	
	var speed_change = int(Input.is_action_pressed("speed_increase")) - int(Input.is_action_pressed("speed_decrease"))
	
	if Input.is_action_pressed("align_rotation"):
		var k = 1.0 - pow(0.05, delta)
		rotation_object.transform = Transform3D(
			lerp(rotation_object.basis.x, round(rotation_object.basis.x), k), 
			lerp(rotation_object.basis.y, round(rotation_object.basis.y), k), 
			lerp(rotation_object.basis.z, round(rotation_object.basis.z), k), 
			rotation_object.position).orthonormalized()
