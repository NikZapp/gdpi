extends Node3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var chunk_template = preload("res://chunk.tscn")

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)

func request_all_chunks():
	for z in 16:
		for x in 16:
			raknet.send(protocol.encode("RequestChunkPacket", {
				"x" : x, 
				"z" : z
			}))
			

func _on_packet(packet : Dictionary):
	if packet.packet_name == "ChunkDataPacket":
		print("Got chunk " + str(packet.x) + ":" + str(packet.z))
		#print(packet.data[0].hex_encode())
		var chunk = chunk_template.instantiate()
		add_child(chunk)
		chunk.position = Vector3(packet.x, 0, packet.z) * 16
		chunk.setup_from_data(packet.data[0], packet.data[1])
func _on_chunk():
	pass
