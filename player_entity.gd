extends Node3D

var id = -1
var metadata = {}
var pos = Vector3()
var pitch = 0
var yaw = 0
var speed = Vector3()
var time_since_update = 0
var username = ""
var client_id = -1
var held_item_id = -1
var held_item_aux = -1

func setup_from_packet(packet : Dictionary):
	var player_handler = get_parent()
	player_handler.player_posrot_packet.connect(_on_posrot)
	player_handler.player_motion_packet.connect(_on_motion)
	player_handler.player_equipment_packet.connect(_on_item)
	
	id = packet.entity_id
	client_id = packet.client_id
	username = packet.username
	
	held_item_id = packet.held_item_id
	held_item_aux = packet.held_item_aux
	
	pos = Vector3(packet.x, packet.y, packet.z)
	# The rotation info is swapped for some reason
	# Seriously, people, yaw is left/right rotation and pitch is up/down
	# Is it that hard to remember?!?
	pitch = packet.yaw
	yaw = -packet.pitch
	metadata = packet.metadata
	update_name()
	update_item()

func _process(delta):
	time_since_update += delta
	update_position()

func _on_posrot(packet : Dictionary):
	if packet.entity_id == id:
		pos = Vector3(packet.x, packet.y, packet.z)
		pitch = packet.yaw
		yaw = -packet.pitch
		speed = Vector3()
		time_since_update = 0
		
		update_position()
		update_rotation()

func _on_motion(packet : Dictionary):
	if packet.entity_id == id:
		speed = Vector3(packet.speed_x, packet.speed_y, packet.speed_z) / 20.0 / 64.0
		print(speed)
		time_since_update = 0

func _on_item(packet : Dictionary):
	held_item_id = packet.item_id
	held_item_aux = packet.item_aux
	update_item()

func update_position():
	global_position = pos + speed * time_since_update

@onready var head = $Head
func update_rotation():
	head.rotation_degrees = Vector3(pitch, 0, 0)
	rotation_degrees = Vector3(0, yaw, 0)

@onready var username_label = $Username
func update_name():
	username_label.text = username
	
func update_item():
	$ArmR/HeldItem.set_item(held_item_id, held_item_aux)
	
