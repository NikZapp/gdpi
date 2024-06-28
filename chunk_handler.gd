extends Node3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var chunk_template = preload("res://chunk.tscn")
var uv_mapping = PackedByteArray()

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)
	load_uv_mappings("res://assets/data/uv.txt")

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


func load_uv_mappings(filepath : String):
	uv_mapping.resize(256*16*6)
	uv_mapping.fill(0)
	var mapping_file = FileAccess.open(filepath, FileAccess.READ)
	var raw_mapping = mapping_file.get_as_text()
	for line in raw_mapping.split("\n"):
		if line == "":
			continue
		var text_data = line.split(" ")
		var block_id = int(text_data[0].split(":")[0])
		var block_data = int(text_data[0].split(":")[1])
		var side_y_neg = int(text_data[1])
		var side_y_pos = int(text_data[2])
		var side_x_neg = int(text_data[3])
		var side_x_pos = int(text_data[4])
		var side_z_neg = int(text_data[5])
		var side_z_pos = int(text_data[6])
		
		var cursor = (block_id * 16 + block_data) * 6
		uv_mapping[cursor + 0] = side_y_neg
		uv_mapping[cursor + 1] = side_y_pos
		uv_mapping[cursor + 2] = side_x_neg
		uv_mapping[cursor + 3] = side_x_pos
		uv_mapping[cursor + 4] = side_z_neg
		uv_mapping[cursor + 5] = side_z_pos
	

func block_to_texture(id : int, data : int, side : int) -> int:
	return uv_mapping[(id * 16 + data) * 6 + side]


func _on_chunk():
	pass
