extends Node3D
@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var entity_template = preload("res://template_entity.tscn")
var entities : Dictionary

signal entity_posrot_packet(packet : Dictionary)
signal entity_motion_packet(packet : Dictionary)
signal remove_entity_packet(packet : Dictionary)

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)

func _process(delta):
	pass

func _on_packet(packet : Dictionary) -> void:
	match packet.packet_name:
		"AddMobPacket":
			var entity = entity_template.instantiate()
			add_child(entity)
			entity.setup_from_packet(packet)
			entities[packet.entity_id] = entity
		"MoveEntityPacket_PosRot":
			entity_posrot_packet.emit(packet)
		"SetEntityMotionPacket":
			entity_motion_packet.emit(packet)
		"RemoveEntityPacket":
			var entity = entities.get(packet.entity_id)
			if entity:
				entity.queue_free()
			remove_entity_packet.emit(packet)
		_:
			print(packet.packet_name)
