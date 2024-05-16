extends Node3D

var id = -1
var type = -1
var metadata = {}
var pos = Vector3()
var pitch = 0
var yaw = 0
var speed = Vector3()
var time_since_update = 0

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
	entity_handler.entity_motion_packet.connect(_on_motion)
	entity_handler.entity_data_packet.connect(_on_data)
	
	id = packet.entity_id
	type = packet.type
	pos = Vector3(packet.x, packet.y, packet.z)
	# The rotation info is swapped for some reason
	# Seriously, people, yaw is left/right rotation and pitch is up/down
	# Is it that hard to remember?!?
	pitch = packet.yaw
	yaw = -packet.pitch
	metadata = packet.metadata
	
	update_label()

func _process(delta):
	time_since_update += delta
	update_position()

func _on_posrot(packet : Dictionary):
	if packet.entity_id == id:
		## Calculate position difference from projected
		#var old_pos = global_position
		#var d = old_pos.distance_to(Vector3(packet.x, packet.y, packet.z))
		#var entity_handler = get_parent()
		#entity_handler.difference_sum += d
		#entity_handler.difference_amount += 1
		
		pos = Vector3(packet.x, packet.y, packet.z)
		pitch = packet.yaw
		yaw = -packet.pitch
		speed = Vector3()
		time_since_update = 0
		
		update_position()
		update_rotation()

func _on_motion(packet : Dictionary):
	# 8 0.23636446280308 (100826 samples)
	# 16 0.12661363518643 (99978 samples)
	# 32 0.09458431864551 (100129 samples)
	# 64 0.10058967609474 (101887 samples)
	#      66 0.09069474148566 (101725 samples)
	#     68 0.08721365046648 (102081 samples)
	#      70 0.08873273082801 (101329 samples)
	#    72 0.09417275581642 (100979 samples)
	#     76 0.09065284748929 (103181 samples)
	#   80 0.09531888150245 (101864 samples)
	#    88 0.09459009651092 (101038 samples)
	#  96 0.0958249159751 (100284 samples)
	#   1120.095435536551 (100939 samples)
	# 128 0.10415581387495 (99785 samples)
	# 256 0.10226640528001 (100339 samples)
	if packet.entity_id == id:
		speed = Vector3(packet.speed_x, packet.speed_y, packet.speed_z) / 20.0 / 64.0
		time_since_update = 0

func _on_data(packet : Dictionary):
	metadata.merge(packet.metadata, true)
	update_label()
	
func update_position():
	global_position = pos + speed * time_since_update

func update_rotation():
	rotation_degrees = Vector3(pitch, yaw, 0)

@onready var info_label = $Label3D
func update_label():
	info_label.text = type_to_name.get(type, "UNKNOWN") + " id:" + str(id) + "\n"
	info_label.text += "data:" + str(metadata)
	
