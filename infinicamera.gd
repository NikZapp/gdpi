extends Camera3D

@export var position_object_path : NodePath
@export var rotation_object_path : NodePath
@onready var position_object = get_node(position_object_path)
@onready var rotation_object = get_node(rotation_object_path)

var speed_exponent = 1
var speed_exponent_change_speed = 1
var speed = 20
var rotation_speed = deg_to_rad(40)

func _ready():
	pass

func _process(delta):
	var direction = Vector3.ZERO
	direction.z = int(Input.is_action_pressed("move_backward")) - int(Input.is_action_pressed("move_forward"))
	direction.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	direction.y = int(Input.is_action_pressed("move_up")) - int(Input.is_action_pressed("move_down"))
	
	position_object.position += rotation_object.transform.basis * direction * pow(speed, speed_exponent) * delta
	
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
	speed_exponent += speed_exponent_change_speed * speed_change * delta
	$CanvasLayer/Label.text = "Speed Exponent:" + str(speed_exponent) + "\n"
	$CanvasLayer/Label.text += "Speed:" + str(pow(speed, speed_exponent)) + "\n"
	match speed_change:
		1:
			$CanvasLayer/Label.text += "Increasing\n"
		-1:
			$CanvasLayer/Label.text += "Decreasing\n"
		0:
			$CanvasLayer/Label.text += "\n"
	
	if Input.is_action_pressed("align_rotation"):
		var k = 1.0 - pow(0.05, delta)
		rotation_object.transform = Transform3D(
			lerp(rotation_object.basis.x, round(rotation_object.basis.x), k), 
			lerp(rotation_object.basis.y, round(rotation_object.basis.y), k), 
			lerp(rotation_object.basis.z, round(rotation_object.basis.z), k), 
			rotation_object.position).orthonormalized()
			
	if Input.is_action_pressed("align_position"):
		var k = 1.0 - pow(0.01, delta)
		position_object.position = lerp(position_object.position, round(position_object.position), k)
	$CanvasLayer/Label.text += "O: " + str(position_object.transform.origin) + "\n"
	$CanvasLayer/Label.text += " x: " + str(rotation_object.transform.basis.x) + "\n"
	$CanvasLayer/Label.text += " y: " + str(rotation_object.transform.basis.y) + "\n"
	$CanvasLayer/Label.text += " z: " + str(rotation_object.transform.basis.z) + "\n"
	$CanvasLayer/Label.text += "FPS: " + str(Engine.get_frames_per_second()) + "\n"
