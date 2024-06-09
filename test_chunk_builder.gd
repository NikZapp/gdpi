extends Node3D

var data : PackedByteArray

func add_face(a : Vector3, b : Vector3, c : Vector3, uv_index : int):
	# XXXXXXXX YYYYYYYY ZZZZZZZZ delta> xxxx:xxxx yyyy:yyyy zzzz:zzzz UV_INDEX YYYY-XYZ
	# XXXXXXXX XYYYYYYY YYYYYZZZ ZZZZZZxx xxXXXXyy yyYYYYzz zzZZZZ-- UUUUVVVV
	# XXXXXXXX YYYYYYYY ZZZZZZZZ XYYYYZxx yyzzSSss DDDDDDDD UUUUVVVV --------
	# Example plane:
	# 00000000 00010000 00000000 00000010 01000010 11111111 00000011 --------
	# 00 10 00 02 42 FF 03 --
	# 00 10 00 02 43 ff 03 00
	# Should be grass at 0 0 facing -Z
	# add 1 to deltas when decoding!
	
	var face_data : PackedByteArray = []
	face_data.resize(8)
	a *= 16
	b *= 16
	c *= 16
	
	# origin point
	face_data[0] = int(a.x) & 0xff
	face_data[1] = int(a.y) & 0xff
	face_data[2] = int(a.z) & 0xff
	face_data[3] = ((int(a.x) & 16) << 3) | ((int(a.y) & 0xf00) >> 5) | ((int(a.z) & 16) >> 2)
	
	# deltas
	var dB = b - a
	var dC = c - a
	var dXt = (int(int(dB.x) != 0) << 1) | int(int(dC.x) != 0)
	var dYt = (int(int(dB.y) != 0) << 1) | int(int(dC.y) != 0)
	var dZt = (int(int(dB.z) != 0) << 1) | int(int(dC.z) != 0)
	
	# delta toggles
	face_data[3] |= dXt
	face_data[4] = (dYt << 6) | (dZt << 4)
	
	# signs and deltas
	var S1 = 0
	var S2 = 0
	var s1 = 0
	var s2 = 0
	var d1 = 0
	var d2 = 0
	# 1 = negative
	# 0 = positive
	# Delta +1 !!!
	
	if int(dB.x) != 0:
		# first sign is X
		S1 = int(int(dB.x) < 0)
		d1 = int(abs(dB.x)) - 1
	else:
		# first sign is Y
		S1 = int(int(dB.y) < 0)
		d1 = int(abs(dB.y)) - 1
	
	if int(dB.z) != 0:
		# second sign is Z
		S2 = int(int(dB.z) < 0)
	else:
		# second sign is Y
		S2 = int(int(dB.y) < 0)
	
	
	if int(dC.x) != 0:
		# first sign is X
		s1 = int(int(dC.x) < 0)
		d2 = int(abs(dC.x)) - 1
	else:
		# first sign is Y
		s1 = int(int(dC.y) < 0)
		d2 = int(abs(dC.y)) - 1
	
	if int(dC.z) != 0:
		# second sign is Z
		s2 = int(int(dC.z) < 0)
	else:
		# second sign is Y
		s2 = int(int(dC.y) < 0)
	
	face_data[4] |= (S1 << 3) | (S2 << 2) | (s1 << 1) | s2
	
	# deltas
	face_data[5] = ((int(d1) & 0xf) << 4) | (int(d2) & 0xf)
	
	# uv
	face_data[6] = uv_index
	
	data.append_array(face_data)


# Mesher based on https://github.com/xen-42/Minecraft-Clone/blob/dd4e4e898864ed7e841a7336cd5f8b3f7e0de04f/Chunk.gd

var block_ids : PackedByteArray = []
var block_aux : PackedByteArray = []
var loaded : bool = false

const step_x = 1 << 11
const step_y = 1
const step_z = 1 << 7

func setup_from_data(blocks : PackedByteArray, data : PackedByteArray):
	block_ids = blocks
	block_aux = data
	loaded = true
	build_mesh()

const cube_v_set : PackedVector3Array = [
	Vector3(0,0,0),
	Vector3(0,0,1),
	Vector3(0,1,0),
	Vector3(0,1,1),
	Vector3(1,0,0),
	Vector3(1,0,1),
	Vector3(1,1,0),
	Vector3(1,1,1)
]

# Faces as vertex id lists
# 1 2
# 3 4
const PosX : PackedByteArray = [7, 6, 5, 4]
const NegX : PackedByteArray = [2, 3, 0, 1]
const PosZ : PackedByteArray = [3, 7, 1, 5]
const NegZ : PackedByteArray = [6, 2, 4, 0]
const PosY : PackedByteArray = [2, 6, 3, 7]
const NegY : PackedByteArray = [0, 1, 4, 5]
# Faces are the same as in minecraft
const uv_offset = [
	Vector2(0, 0),
	Vector2(1, 0),
	Vector2(0, 1),
	Vector2(1, 1)
]

const atlas_size = 16


var collision_surface = SurfaceTool.new()
var visual_surface = SurfaceTool.new()

func construct_face(vertex_set : PackedVector3Array, face_data : PackedByteArray, pos : Vector3, uv : Vector2, collision_enabled : bool, normal : Vector3):
	var a = pos + vertex_set[face_data[0]]
	var b = pos + vertex_set[face_data[1]]
	var c = pos + vertex_set[face_data[2]]
	var d = pos + vertex_set[face_data[3]]
	
	add_face(a, b, c, uv.x * 16.0 + uv.y)
	return
	var uv_a = (uv + uv_offset[0]) / atlas_size
	var uv_b = (uv + uv_offset[1]) / atlas_size
	var uv_c = (uv + uv_offset[2]) / atlas_size
	var uv_d = (uv + uv_offset[3]) / atlas_size
	
	visual_surface.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c], [], [], [normal, normal, normal])
	visual_surface.add_triangle_fan([b, d, c], [uv_b, uv_d, uv_c], [], [], [normal, normal, normal])
	
	if collision_enabled:
		pass
		#collision_surface.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c])
		#collision_surface.add_triangle_fan([b, d, c], [uv_b, uv_d, uv_c])

func is_block_transparent(id : int) -> bool:
	return id == 0

func build_mesh():
	data.clear()
	simple_chunk()
	return
	var mesh = ArrayMesh.new()
	var mesh_instance = $MeshInstance3D
	
	var cursor = 0
	visual_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Only build +x, +y, +z faces.
	for x in 16:
		for z in 16:
			for y in 128:
				var pos = Vector3(x, y, z)
				var block = block_ids[cursor]
				
				var is_solid = true
				if is_block_transparent(block):
					# Build faces inwards
					if (x != 15) and not is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, NegX, pos + Vector3(1,0,0), Vector2.ZERO, is_solid, Vector3(-1,0,0))
					if (y != 127) and not is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, NegY, pos + Vector3(0,1,0), Vector2.ZERO, is_solid, Vector3(0,-1,0))
					if (z != 15) and not is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, NegZ, pos + Vector3(0,0,1), Vector2.ZERO, is_solid, Vector3(0,0,-1))
				else:
					# Build faces outwards
					if (x == 15) or is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, PosX, pos, Vector2.ZERO, is_solid, Vector3(1,0,0))
					if (y == 127) or is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, PosY, pos, Vector2.ZERO, is_solid, Vector3(0,1,0))
					if (z == 15) or is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, PosZ, pos, Vector2.ZERO, is_solid, Vector3(0,0,1))
				
				cursor += 1
	
	# Negative x wall
	cursor = 0
	for z in 16:
		for y in 128:
			var block = block_ids[cursor]
			var is_transparent = is_block_transparent(block)
			var is_solid = true
			if not is_transparent:
				construct_face(cube_v_set, NegX, Vector3(0, y, z), Vector2.ZERO, is_solid, Vector3(1,0,0))
			cursor += 1
	
	# Negative z wall
	cursor = 0
	for x in 16:
		for y in 128:
			var block = block_ids[cursor]
			var is_transparent = is_block_transparent(block)
			var is_solid = true
			if not is_transparent:
				construct_face(cube_v_set, NegZ, Vector3(x, y, 0), Vector2.ZERO, is_solid, Vector3(0,0,1))
			cursor += 1
		cursor += step_x - 128
	print("Data size: " + str(data.size()) + " bytes")
	var data_image = Image.create_from_data(data.size() / 4, 1, false, Image.FORMAT_RGBA8, data)
	
	(mesh_instance as MeshInstance3D).get_active_material(0).set_shader_parameter("mesh_data", ImageTexture.create_from_image(data_image))
	#visual_surface.commit(mesh)
	#mesh_instance.mesh = mesh
	
	#print("Mesh contains " + str(mesh.surface_get_array_len(0)), " vertices.")
	#for child in get_children():
	#	if child is MeshInstance3D:
	#		child.queue_free()
	#add_child(mesh_instance)

static func coords_to_offset(x : int, y : int, z : int):
	return (((x & 0x0f) << 11) + ((z & 0x0f) << 7) + (y & 0x7f))

func simple_chunk():
	data.clear()
	add_face(Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 0), 3)
	print(data.hex_encode())
	# XXXXXXXX YYYYYYYY ZZZZZZZZ XYYYYZxx yyzzSSss DDDDDDDD UUUUVVVV --------
	data = PackedByteArray([0,0,0,0,0,128,0,0])
	var mesh_instance = $MeshInstance3D
	
	var data_image = Image.create_from_data(data.size() / 4, 1, false, Image.FORMAT_RF, data)
	
	(mesh_instance as MeshInstance3D).get_active_material(0).set_shader_parameter("mesh_data", ImageTexture.create_from_image(data_image))
