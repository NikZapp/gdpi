extends Node3D
@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var entity_template = preload("res://template_entity.tscn")
var entities : Dictionary

const profile_position_estimator = false
var difference_sum = 0
var difference_amount = 0
var timer = 6000

signal entity_posrot_packet(packet : Dictionary)
signal entity_motion_packet(packet : Dictionary)
signal remove_entity_packet(packet : Dictionary)
signal entity_data_packet(packet : Dictionary)
signal entity_event_packet(packet : Dictionary)

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)

func _process(delta):
	if profile_position_estimator:
		timer += delta
		if timer >= 60:
			timer -= 60
			print("Average position estimation error: " + str(difference_sum / max(1, difference_amount)) + " (" + str(difference_amount) + " samples)")
			difference_sum = 0
			difference_amount = 0

func _on_packet(packet : Dictionary) -> void:
	# Profiling statement: The match is fine, as it is matched per packet.
	# The signals are also not an issue, nor is it the fact that all entities
	# need to check ids
	# Well, at least its not an issue yet.
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
		"SetEntityDataPacket":
			entity_data_packet.emit(packet)
		"EntityEventPacket":
			entity_event_packet.emit(packet)
		_:
			pass#print(packet.packet_name)
