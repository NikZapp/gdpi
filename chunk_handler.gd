extends Node3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var chunk_template = preload("res://chunk.tscn")

var world_blocks = PackedByteArray()
var world_data = PackedByteArray()
var loaded_chunks = Dictionary()

func _ready():
	world_blocks.resize(256*128*256)
	world_data.resize(256*128*256 / 2)
	world_blocks.fill(35)
	
	network_handler.received_packet_decoded.connect(_on_packet)
	BlockUtils.setup()
	
func request_all_chunks():
	for z in 16:
		for x in 16:
			raknet.send(protocol.encode("RequestChunkPacket", {
				"x" : x, 
				"z" : z
			}))

@onready var chunks_built = false
func _on_packet(packet : Dictionary):
	match packet.packet_name:
		"ChunkDataPacket":
			loaded_chunks[Vector2(packet.x, packet.z)] = true
			print("Got chunk " + str(packet.x) + ":" + str(packet.z) + " (" + str(len(loaded_chunks.keys())) + "/256)")
			var chunk_blocks : PackedByteArray = packet.data[0]
			var chunk_data : PackedByteArray = packet.data[1]
			# Make image from the data
			# For now - just for fun
			# Later useful in the ~O(1) mesher
			##var chunk_name = "x" + str(packet.x) + "y*z" + str(packet.z)
			##Image.create_from_data(128, 256, false, Image.FORMAT_R8, chunk_blocks).save_png("res://export_data/chunks/blocks/" + chunk_name + ".png")
			##Image.create_from_data(128, 128, false, Image.FORMAT_R8, chunk_data).save_png("res://export_data/chunks/data/" + chunk_name + ".png")
			
			var chunk_cursor = 0
			for x_offset in 16:
				var x = x_offset + packet.x * 16
				for z_offset in 16:
					var z = z_offset + packet.z * 16
					var cursor = (x << 15) + (z << 7)
					for y in 128:
						world_blocks[cursor] = chunk_blocks[chunk_cursor]
						if cursor & 1:
							world_data[cursor >> 1] = chunk_data[chunk_cursor >> 1]
						chunk_cursor += 1
						cursor += 1
		"PlaceBlockPacket":
			print("Placed block")
			var cursor = coords_to_offset(packet.x, packet.y, packet.z)
			var chunk_x = packet.x >> 4
			var chunk_z = packet.z >> 4
			var block = packet.block_id
			var data = packet.block_aux
			
			var search_name = "x" + str(chunk_x) + "y*z" + str(chunk_z)
			var found : bool = false
			var chunk
			
			for c in get_children():
				if c.name == search_name:
					found = true
					chunk = c
					break
			
			world_blocks[cursor] = block
			world_data[cursor >> 1] &= 0xf0 >> ((cursor & 1) * 4)
			world_data[cursor >> 1] |= data << ((cursor & 1) * 4)
			if found:
				chunk.setup_from_data(world_blocks, world_data, Vector2(chunk_x, chunk_z))
			else:
				print("Block placed in an unloaded chunk, dropping packet!")
		"RemoveBlockPacket":
			print("Removed block")
			var cursor = coords_to_offset(packet.x, packet.y, packet.z)
			var chunk_x = packet.x >> 4
			var chunk_z = packet.z >> 4
			
			var search_name = "x" + str(chunk_x) + "y*z" + str(chunk_z)
			var found : bool = false
			var chunk
			
			for c in get_children():
				if c.name == search_name:
					found = true
					chunk = c
					break
			
			world_blocks[cursor] = 0
			world_data[cursor >> 1] &= 0xf0 >> ((cursor & 1) * 4)
			if found:
				chunk.setup_from_data(world_blocks, world_data, Vector2(chunk_x, chunk_z))
			else:
				print("Block removed in an unloaded chunk, dropping packet!")
		"UpdateBlockPacket":
			print("Updated block")
			var cursor = coords_to_offset(packet.x, packet.y, packet.z)
			var chunk_x = packet.x >> 4
			var chunk_z = packet.z >> 4
			var block = packet.block_id
			var data = packet.block_aux
			
			var search_name = "x" + str(chunk_x) + "y*z" + str(chunk_z)
			var found : bool = false
			var chunk
			
			for c in get_children():
				if c.name == search_name:
					found = true
					chunk = c
					break
			
			world_blocks[cursor] = block
			world_data[cursor >> 1] &= 0xf0 >> ((cursor & 1) * 4)
			world_data[cursor >> 1] |= data << ((cursor & 1) * 4)
			if found:
				chunk.setup_from_data(world_blocks, world_data, Vector2(chunk_x, chunk_z))
			else:
				print("Block updated in an unloaded chunk, dropping packet!")
	if len(loaded_chunks.keys()) == 256 and not chunks_built:
		var start_time = Time.get_ticks_msec()
		for x in 16:
			for z in 16:
				print("Building chunk ", x, ":", z)
				var chunk = chunk_template.instantiate()
				chunk.name = "x" + str(x) + "y*z" + str(z)
				add_child(chunk)
				chunk.setup_from_data(world_blocks, world_data, Vector2(x, z))
		chunks_built = true
		var end_time = Time.get_ticks_msec()
		var time = end_time - start_time
		print("Took ", time, "ms to build 256 chunks.")
		print("Average: ", time/256, "ms/c")


func get_water_height(pos : Vector3) -> float: # , const Material* pCheckMtl
	var iBias : int = 0
	var fHeight : float = 0.0
	for i in 4:
		var checkX : int = pos.x - (i & 1)
		var checkY : int = pos.y
		var checkZ : int = pos.z - ((i >> 1) & 1)
		
		var check_pos = pos - Vector3(i & 1, 0, i >> 1)
		
		if BlockUtils.is_water(get_block(check_pos + Vector3(0,1,0))):
			return 1.0
		
		if BlockUtils.is_water(get_block(check_pos)):
			#print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA LETS GOOOOOOOOOOOOO")
			var data = get_data(check_pos)
			if data >= 8 or data == 0:
				fHeight += data_to_liquid_volume(get_data(check_pos)) * 10.0
				iBias += 10
			fHeight += data_to_liquid_volume(get_data(check_pos))
			iBias += 1
			continue
		
		if BlockUtils.is_transparent(get_block(check_pos)):
			fHeight += 1.0
			iBias += 1
	return 1.0 - (fHeight / float(iBias))

func data_to_liquid_volume(data : int) -> float:
	if data >= 8:
		data = 0
	return (data + 1.0) / 9.0

func get_block(pos : Vector3) -> int:
	if (0 <= pos.x) and (pos.x <= 255) and (0 <= pos.y) and (pos.y <= 127) and (0 <= pos.z) and (pos.z <= 255):
		return world_blocks[coords_to_offset(pos.x, pos.y, pos.z)]
	return 0

func get_data(pos : Vector3) -> int:
	if (0 <= pos.x) and (pos.x <= 255) and (0 <= pos.y) and (pos.y <= 127) and (0 <= pos.z) and (pos.z <= 255):
		var cursor = coords_to_offset(pos.x, pos.y, pos.z)
		return world_data[cursor >> 1] >> 4 if (cursor % 2) else world_data[cursor >> 1] & 15
	return 0

static func coords_to_offset(x : int, y : int, z : int):
	return (((x & 0xff) << 15) + ((z & 0xff) << 7) + (y & 0x7f))
