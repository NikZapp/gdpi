extends Node3D
@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var player_scene = preload("res://player_entity.tscn")
var players : Dictionary

signal player_posrot_packet(packet : Dictionary)
signal player_motion_packet(packet : Dictionary)
signal remove_player_packet(packet : Dictionary)
signal player_equipment_packet(packet : Dictionary)

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)

func _on_packet(packet : Dictionary) -> void:
	match packet.packet_name:
		"AddPlayerPacket":
			var player = player_scene.instantiate()
			add_child(player)
			player.setup_from_packet(packet)
			players[packet.entity_id] = player
		"MovePlayerPacket":
			player_posrot_packet.emit(packet)
		"SetEntityMotionPacket":
			player_motion_packet.emit(packet)
		"PlayerEquipmentPacket":
			player_equipment_packet.emit(packet)
		"RemovePlayerPacket":
			var player = players.get(packet.entity_id)
			if player:
				player.queue_free()
			remove_player_packet.emit(packet)
