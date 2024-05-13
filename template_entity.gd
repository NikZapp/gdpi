extends Node3D

var id = -1
var type = -1
var metadata = {}
var pos = Vector3()
var pitch = 0
var yaw = 0

const type_to_name = {
	0: "Player",
	10: "Chicken",
	11: "Cow",
	12: "Pig",
	13: "Sheep",
	32: "Zombie",
	33: "Creeper",
	34: "Skeleton",
	35: "Spider",
	36: "ZombiePigman",
	64: "Item",
	65: "TNT",
	66: "FallingBlock",
	80: "Arrow",
	81: "Snowball",
	82: "Egg",
	83: "Painting"
}

func setup_from_packet(packet : Dictionary):
	var entity_handler = get_parent()
	entity_handler.entity_posrot_packet.connect(_on_posrot)
	id = packet.entity_id
	type = packet.type
	pos = Vector3(packet.x, packet.y, packet.z)
	# The rotation info is swapped for some reason
	# Seriously, people, yaw is left/right rotation and pitch is up/down
	# Is it that hard to remember?!?
	pitch = packet.yaw
	yaw = -packet.pitch
	metadata = packet.metadata
	print("NEW ENTITY ", packet)

func _process(delta):
	$Label3D.text = type_to_name.get(type, "UNKNOWN") + " id:" + str(id) + "\n"
	$Label3D.text += "data:" + str(metadata) + "\n"
	$Label3D.text += str(pos) + " : " + str(pitch) + "," + str(yaw)
	global_position = pos
	rotation_degrees = Vector3(pitch, yaw, 0)

func _on_posrot(packet : Dictionary):
	if packet.entity_id == id:
		pos = Vector3(packet.x, packet.y, packet.z)
		pitch = packet.yaw
		yaw = -packet.pitch
