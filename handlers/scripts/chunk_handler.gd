extends Node3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
var chunk_template = preload("res://objects/chunk.tscn")

var world_blocks = PackedByteArray()
var world_data = PackedByteArray()
var chunk_statuses = Dictionary()
var chunk_generation_threads = Dictionary()
var chunk_status_mutex = Mutex.new()
var raknet_mutex = Mutex.new()

enum ChunkStatus {
	UNLOADED,
	SENT,
	RECEIVED,
	BUILT
}
	

func _ready():
	world_blocks.resize(256*128*256)
	world_data.resize(256*128*256 / 2)
	world_blocks.fill(35)
	
	network_handler.received_packet_decoded.connect(_on_packet)
	BlockUtils.setup()

func request_all_chunks():
	for z in 16:
		for x in 16:
			if Vector2(x, z) in chunk_generation_threads:
				chunk_status_mutex.lock()
				chunk_statuses[Vector2(x, z)] = ChunkStatus.UNLOADED
				chunk_status_mutex.unlock()
			else:
				var thread = Thread.new()
				chunk_generation_threads[Vector2(x, z)] = thread
				thread.start(load_chunk.bind(x, z, ChunkStatus.UNLOADED))


func load_chunk(x, z, initial_status):
	while true:
		chunk_status_mutex.lock()
		var status = chunk_statuses.get(Vector2(x, z), initial_status)
		chunk_status_mutex.unlock()
		var old_status = status
		
		#print("CHUNK ", x, " ", z, " : ", ["UNLOADED", "ASKED", "RECEIVED", "BUILT"][status])
		match status:
			ChunkStatus.UNLOADED:
				raknet_mutex.lock()
				raknet.send(protocol.encode("RequestChunkPacket", {
					"x" : x, 
					"z" : z
				}))
				raknet_mutex.unlock()
				status = ChunkStatus.SENT
				await get_tree().create_timer(1).timeout
			ChunkStatus.SENT:
				await get_tree().create_timer(5).timeout
				chunk_status_mutex.lock()
				if chunk_statuses.get([Vector2(x, z)], initial_status) == ChunkStatus.SENT:
					raknet_mutex.lock()
					raknet.send(protocol.encode("RequestChunkPacket", {
						"x" : x, 
						"z" : z
					}))
					raknet_mutex.unlock()
				chunk_status_mutex.unlock()
				
			ChunkStatus.RECEIVED:
				var can_build = true
				for dx in [-1, 0, 1]:
					var test_x = clamp(x + dx, 0, 15)
					for dz in [-1, 0, 1]:
						var test_z = clamp(z + dz, 0, 15)
						var test_status = chunk_statuses.get(Vector2(test_x, test_z), initial_status)
						if test_status < ChunkStatus.RECEIVED:
							can_build = false
				if can_build:
					#print("Building chunk ", x, ":", z)
					var chunk = chunk_template.instantiate()
					chunk.name = "x" + str(x) + "y*z" + str(z)
					add_child(chunk)
					chunk.setup_from_data(world_blocks, world_data, Vector2(x, z))
					status = ChunkStatus.BUILT
				else:
					await get_tree().create_timer(1).timeout
			ChunkStatus.BUILT:
				pass
				
		chunk_status_mutex.lock()
		if old_status == chunk_statuses.get(Vector2(x, z), initial_status):
			chunk_statuses[Vector2(x, z)] = status
		chunk_status_mutex.unlock()
		if status == ChunkStatus.BUILT:
			break

func _process(_delta):
	# Chunk sorting by distance
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var chunks = get_children()
	var cam_pos = camera.global_position / 16.0
	cam_pos = Vector2(cam_pos.x, cam_pos.z)
	chunks.sort_custom(func(a, b):
		return cam_pos.distance_squared_to(a.chunk_offset) < cam_pos.distance_squared_to(b.chunk_offset)
	)
	for chunk in chunks:
		move_child(chunk, get_child_count() - 1)
		var dist = camera.global_position.distance_squared_to(chunk.global_position)
		if chunk.get_child(0).material_override:
			chunk.get_child(0).material_override.render_priority = int(dist / 10.0)

func update_light_data():
	pass

@onready var chunks_built = false
func _on_packet(packet : Dictionary):
	match packet.packet_name:
		"ChunkDataPacket":
			#print("Got chunk " + str(packet.x) + ":" + str(packet.z))
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
			chunk_status_mutex.lock()
			chunk_statuses[Vector2(packet.x, packet.z)] = ChunkStatus.RECEIVED
			chunk_status_mutex.unlock()
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


func get_water_height(pos : Vector3) -> float: # , const Material* pCheckMtl
	var sample_count : int = 0
	var sample_height_sum : float = 0.0
	for i in 4:
		var check_pos = pos - Vector3(i & 1, 0, i >> 1)
		
		if BlockUtils.is_water(get_block(check_pos + Vector3(0,1,0))):
			return 1.0
		
		if BlockUtils.is_water(get_block(check_pos)):
			var data = get_data(check_pos)
			if data >= 8 or data == 0:
				sample_height_sum += data_to_liquid_volume(get_data(check_pos)) * 10.0
				sample_count += 10
			sample_height_sum += data_to_liquid_volume(get_data(check_pos))
			sample_count += 1
			continue
		
		if BlockUtils.is_transparent(get_block(check_pos)):
			sample_height_sum += 1.0
			sample_count += 1
	return 1.0 - (sample_height_sum / float(sample_count))

func data_to_liquid_volume(data : int) -> float:
	if data >= 8:
		data = 0
	return (data + 1.0) / 9.0

func get_block(pos : Vector3) -> int:
	if (0 > pos.y) or (pos.y > 127):
		return 0
	if (0 <= pos.x) and (pos.x <= 255) and (0 <= pos.z) and (pos.z <= 255):
		return world_blocks[coords_to_offset(pos.x, pos.y, pos.z)]
	return 95 # Invisible bedrock

func get_data(pos : Vector3) -> int:
	if (0 <= pos.x) and (pos.x <= 255) and (0 <= pos.y) and (pos.y <= 127) and (0 <= pos.z) and (pos.z <= 255):
		var cursor = coords_to_offset(pos.x, pos.y, pos.z)
		return world_data[cursor >> 1] >> 4 if (cursor % 2) else world_data[cursor >> 1] & 15
	return 0

func get_collision_aabb(pos : Vector3) -> AABB:
	return AABB(pos, Vector3(1, 1, 1)) # TODO: implement this!

static func coords_to_offset(x : int, y : int, z : int):
	return (((x & 0xff) << 15) + ((z & 0xff) << 7) + (y & 0x7f))
