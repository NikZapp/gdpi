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
var decoded_metadata = {}

func setup_from_packet(packet : Dictionary):
	var player_handler = get_parent()
	player_handler.player_posrot_packet.connect(_on_posrot)
	player_handler.player_motion_packet.connect(_on_motion)
	player_handler.player_equipment_packet.connect(_on_item)
	player_handler.player_data_packet.connect(_on_data)
	
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
	update_label()
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
		if packet.speed_y == -627:
			# Gravity cancelation on surfaces
			packet.speed_y = 0
		speed = Vector3(packet.speed_x, packet.speed_y, packet.speed_z) / 1024.0
		time_since_update = 0

func _on_item(packet : Dictionary):
	held_item_id = packet.item_id
	held_item_aux = packet.item_aux
	update_item()

func _on_data(packet : Dictionary):
	metadata.merge(packet.metadata, true)
	update_label()

func approach_forever(time, limit):
	return limit * (1.0 - (1.0 / max(1.0, time + 1.0)))

func update_position():
	global_position = pos + speed * approach_forever(time_since_update, 1)

@onready var head = $Head
func update_rotation():
	head.rotation_degrees = Vector3(pitch, 0, 0)
	rotation_degrees.y = yaw
	rotation_degrees.x = 90 if decoded_metadata.get("sleeping", false) else 0

@onready var username_label = $Username
func update_label():
	username_label.text = username + "\n" + str(metadata)
	
func update_item():
	$ArmR/HeldItem.set_item(held_item_id, held_item_aux)
	
func decode_metadata():
	decoded_metadata.sleeping = metadata.get(16, [0, 0])[1] == 2
	decode_metadata()
