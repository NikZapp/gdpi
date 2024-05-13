extends Node3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
@onready var sun = $Sun
@export var sunlight_gradient : Gradient
@export var sky_gradient : Gradient

var last_time = 0
var ticks_since_update = 0
const ticks_in_day = 19200

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)

func _process(delta):
	ticks_since_update += delta * 20
	
	var projected_time = last_time + ticks_since_update
	var days = projected_time / ticks_in_day
	var time_of_day = fmod(days, 1.0)
	
	sun.rotation_order = EULER_ORDER_YZX
	sun.rotation_degrees = Vector3(-360 * days, 90, 30)
	sun.light_color = sunlight_gradient.sample(time_of_day)

func _on_packet(packet : Dictionary):
	if packet.packet_name == "SetTimePacket":
		last_time = packet.time
		ticks_since_update = 0
