extends Node3D

@export var chunk_material : Material
@export var chunk_water_material : Material
var block_ids : PackedByteArray = []
var block_aux : PackedByteArray = []
var chunk_offset : Vector2 = Vector2()
var loaded : bool = false
@onready var chunk_handler = get_parent()
var uv_map_function
var is_transparent

const step_x = 1 << 15
const step_y = 1
const step_z = 1 << 7

func setup_from_data(blocks : PackedByteArray, data : PackedByteArray, chunk_pos : Vector2):
	block_ids = blocks
	block_aux = data
	chunk_offset = chunk_pos
	loaded = true
	reset_buffers()
	build_mesh()

func update_block(_pos : Vector3, _block : int, _data : int):
	if loaded:
		reset_buffers()
		build_mesh()

func place_block(_pos : Vector3, _block : int, _data : int, _face : Vector3):
	if loaded:
		reset_buffers()
		build_mesh()

func remove_block(_pos : Vector3):
	if loaded:
		reset_buffers()
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

var farmland_v_set : PackedVector3Array = v_set_from_aabb(Vector3.ZERO, Vector3(16, 15, 16))
var bottom_slab_v_set : PackedVector3Array = v_set_from_aabb(Vector3.ZERO, Vector3(16, 8, 16))
var top_slab_v_set : PackedVector3Array = v_set_from_aabb(Vector3(0, 8, 0), Vector3(16, 16, 16))
var snow_v_set : PackedVector3Array = v_set_from_aabb(Vector3(0, 0, 0), Vector3(16, 2, 16))

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

var transform_array = []
var water_transform_array = []
var uv_block_array : PackedByteArray = []
var uv_water_array : PackedByteArray = []
var uv_a_array : PackedByteArray = []
var uv_b_array : PackedByteArray = []
var colors : PackedByteArray = []

var uv_a : Vector2 = Vector2.ZERO
var uv_b : Vector2 = Vector2(16, 16)
var color : Vector3 = Vector3(255, 255, 255)

func reset_buffers():
	transform_array = []
	uv_block_array = []
	uv_a_array = []
	uv_b_array = []
	colors = []
	uv_a = Vector2.ZERO
	uv_b = Vector2(16, 16)
	color = Vector3(255, 255, 255)
	water_transform_array = []
	uv_water_array = []
	
func v_set_from_aabb(a : Vector3, b : Vector3):
	var v_set : PackedVector3Array = []
	
	for x in 2:
		for y in 2:
			for z in 2:
				v_set.append(Vector3(
					b.x if x else a.x,
					b.y if y else a.y,
					b.z if z else a.z
				) / 16.0)
	
	return v_set

func pack_pixel_uv(uv : Vector2) -> int:
	return (int(uv.x) << 4) + int(uv.y)

func pack_two_bytes(a : int, b : int) -> int:
	return (a << 8) + b

func pack_data_to_color(id : int) -> Color:
	# Two bytes per float is bad
	# The best way would be to pack bits into float
	# but this is enough for now
	return Color(
		pack_two_bytes(colors[id*3], colors[id*3 + 1]), # R G
		pack_two_bytes(colors[id*3 + 2], uv_block_array[id]), # B Texture
		pack_two_bytes(uv_a_array[id], uv_b_array[id]), # UV UV
		pack_two_bytes(230, 33) # Random stuff, fill later
	)

func set_uv_bounds(a : Vector2, b: Vector2) -> void:
	uv_a = a
	uv_b = b

func reset_uv_bounds() -> void:
	uv_a = Vector2.ZERO
	uv_b = Vector2(16, 16)

func set_color(r : int, g : int, b: int):
	color = Vector3(r, g, b)

func reset_color():
	color = Vector3(255, 255, 255)

func construct_face(vertex_set : PackedVector3Array, face_data : PackedByteArray, pos : Vector3, block : int, aux : int, side : int):
	var a = pos + vertex_set[face_data[0]]
	var b = pos + vertex_set[face_data[1]]
	var c = pos + vertex_set[face_data[2]]
	#var d = pos + vertex_set[face_data[3]]
	var texture_id = BlockUtils.block_to_texture(block, aux, side)
	
	if block == 2: # Grass block
		match side:
			1:
				set_color(32, 255, 16) # top
			0:
				pass # bottom
			_:
				# sides
				# Check if snow on top:
				if (pos.y != 127) and BlockUtils.is_snow(chunk_handler.get_block(pos + Vector3(0,1,0))):
					texture_id = 0x44
	
	# This breaks lighting somehow ( C -> B )
	transform_array.append(Transform3D(c - a, b - a, (c - a).cross(b - a), a)) # Magic sauce
	uv_block_array.append(texture_id)
	uv_a_array.append(pack_pixel_uv(uv_a))
	uv_b_array.append(pack_pixel_uv(uv_b - Vector2(1, 1)))
	@warning_ignore("narrowing_conversion")
	colors.append(color.x)
	@warning_ignore("narrowing_conversion")
	colors.append(color.y)
	@warning_ignore("narrowing_conversion")
	colors.append(color.z)
	
	if block == 2 and side == 1: # Grass block top
		reset_color()

func construct_face_directly(a : Vector3, b : Vector3, c : Vector3, block : int, aux : int, side : int):
	transform_array.append(Transform3D(c - a, b - a, (c - a).cross(b - a), a)) # Magic sauce
	uv_block_array.append(BlockUtils.block_to_texture(block, aux, side))
	uv_a_array.append(pack_pixel_uv(uv_a))
	uv_b_array.append(pack_pixel_uv(uv_b - Vector2(1, 1)))
	@warning_ignore("narrowing_conversion")
	colors.append(color.x)
	@warning_ignore("narrowing_conversion")
	colors.append(color.y)
	@warning_ignore("narrowing_conversion")
	colors.append(color.z)

func construct_triangle_face(vertex_set : PackedVector3Array, face_data : PackedByteArray, pos : Vector3, block : int, aux : int, side : int):
	var a = pos + vertex_set[face_data[0]]
	var b = pos + vertex_set[face_data[1]]
	var c = pos + vertex_set[face_data[2]]
	var d = pos + vertex_set[face_data[3]]
	#b.y += 1.0
	water_transform_array.append(Transform3D(c - a, d - c, (c - a).cross(d - c), a))
	uv_water_array.append(BlockUtils.block_to_texture(block, aux, side))
	water_transform_array.append(Transform3D(b - a, d - b, (d - b).cross(b - a), a))
	#water_transform_array.append(Transform3D(c - d, b - d, (c - d).cross(b - d), d))
	uv_water_array.append(BlockUtils.block_to_texture(block, aux, side))
	#construct_face(vertex_set, face_data, pos, block, aux, side)
	
func is_block_transparent(id : int) -> bool:
	return BlockUtils.is_transparent(id)

func render_shape_weird_cube(v_set : PackedVector3Array, pos : Vector3, cursor : int, block : int, aux : int, showsides : PackedByteArray, insets : PackedByteArray, skip_side_check : bool):
	var x = round(pos.x)
	var y = round(pos.y)
	var z = round(pos.z)
	# Outwards faces
	if showsides[1] and (skip_side_check or ((y != 127) and block_ids[cursor + step_y] != block and is_block_transparent(block_ids[cursor + step_y]))):
		construct_face(v_set, PosY, pos - Vector3(0, insets[1] / 16.0, 0), block, aux, 1)
	if showsides[3] and (skip_side_check or ((x != 255) and block_ids[cursor + step_x] != block and is_block_transparent(block_ids[cursor + step_x]))):
		construct_face(v_set, PosX, pos - Vector3(insets[3] / 16.0, 0, 0), block, aux, 3)
	if showsides[5] and (skip_side_check or ((z != 255) and block_ids[cursor + step_z] != block and is_block_transparent(block_ids[cursor + step_z]))):
		construct_face(v_set, PosZ, pos - Vector3(0, 0, insets[5] / 16.0), block, aux, 5)
	# Inwards faces
	if showsides[0] and (skip_side_check or ((y != 0) and block_ids[cursor - step_y] != block and is_block_transparent(block_ids[cursor - step_y]))):
		construct_face(v_set, NegY, pos + Vector3(0, insets[0] / 16.0, 0), block, aux, 0)
	if showsides[2] and (skip_side_check or ((x != 0) and block_ids[cursor - step_x] != block and is_block_transparent(block_ids[cursor - step_x]))):
		construct_face(v_set, NegX, pos + Vector3(insets[2] / 16.0, 0, 0), block, aux, 2)
	if showsides[4] and (skip_side_check or ((z != 0) and block_ids[cursor - step_z] != block and is_block_transparent(block_ids[cursor - step_z]))):
		construct_face(v_set, NegZ, pos + Vector3(0, 0, insets[4] / 16.0), block, aux, 4)

func render_shape_cube(v_set : PackedVector3Array, pos : Vector3, cursor : int, block : int, aux : int):
	var x = pos.x
	var y = pos.y
	var z = pos.z
	# Outwards faces
	if (y != 127) and block_ids[cursor + step_y] != block and is_block_transparent(block_ids[cursor + step_y]):
		construct_face(v_set, PosY, pos, block, aux, 1)
	if (x != 255) and block_ids[cursor + step_x] != block and is_block_transparent(block_ids[cursor + step_x]):
		construct_face(v_set, PosX, pos, block, aux, 3)
	if (z != 255) and block_ids[cursor + step_z] != block and is_block_transparent(block_ids[cursor + step_z]):
		construct_face(v_set, PosZ, pos, block, aux, 5)
	# Inwards faces
	if (y != 0) and block_ids[cursor - step_y] != block and is_block_transparent(block_ids[cursor - step_y]):
		construct_face(v_set, NegY, pos, block, aux, 0)
	if (x != 0) and block_ids[cursor - step_x] != block and is_block_transparent(block_ids[cursor - step_x]):
		construct_face(v_set, NegX, pos, block, aux, 2)
	if (z != 0) and block_ids[cursor - step_z] != block and is_block_transparent(block_ids[cursor - step_z]):
		construct_face(v_set, NegZ, pos, block, aux, 4)

func render_shape_pixel_consistent_cube(a : Vector3, b : Vector3, pos : Vector3, block : int, aux : int):
	var v_set = v_set_from_aabb(a, b)
	# -+Y
	set_uv_bounds(Vector2(16,16), Vector2(0,0))
	construct_face(v_set, NegY, pos, block, aux, 0)
	set_uv_bounds(Vector2(a.x, a.z), Vector2(b.x, b.z))
	construct_face(v_set, PosY, pos, block, aux, 1)
	
	# -+X
	set_uv_bounds(Vector2(a.z, 16 - b.y), Vector2(b.z, 16 - a.y))
	construct_face(v_set, NegX, pos, block, aux, 2)
	
	set_uv_bounds(Vector2(16 - b.z, 16 - b.y), Vector2(16 - a.z, 16 - a.y))
	construct_face(v_set, PosX, pos, block, aux, 3)
	# -+Z
	set_uv_bounds(Vector2(16 - b.x, 16 - b.y), Vector2(16 - a.x, 16 - a.y))
	construct_face(v_set, NegZ, pos, block, aux, 4)
	
	set_uv_bounds(Vector2(a.x, 16 - b.y), Vector2(b.x, 16 - a.y))
	construct_face(v_set, PosZ, pos, block, aux, 5)
	reset_uv_bounds()

func render_shape_triangulated_cube(v_set : PackedVector3Array, pos : Vector3, cursor : int, block : int, aux : int):
	var x = pos.x
	var y = pos.y
	var z = pos.z
	# Outwards faces
	if (y != 127) and BlockUtils.get_block_shape(block_ids[cursor + step_y]) != 4:
		construct_triangle_face(v_set, PosY, pos, block, aux, 1)
	if (x != 255) and BlockUtils.is_transparent_except_shape(block_ids[cursor + step_x], 4):
		construct_triangle_face(v_set, PosX, pos, block, aux, 3)
	if (z != 255) and BlockUtils.is_transparent_except_shape(block_ids[cursor + step_z], 4):
		construct_triangle_face(v_set, PosZ, pos, block, aux, 5)
	# Inwards faces
	if (y != 0) and BlockUtils.is_transparent_except_shape(block_ids[cursor - step_y], 4):
		construct_triangle_face(v_set, NegY, pos, block, aux, 0)
	if (x != 0) and BlockUtils.is_transparent_except_shape(block_ids[cursor - step_x], 4):
		construct_triangle_face(v_set, NegX, pos, block, aux, 2)
	if (z != 0) and BlockUtils.is_transparent_except_shape(block_ids[cursor - step_z], 4):
		construct_triangle_face(v_set, NegZ, pos, block, aux, 4)

func render_shape_torch(pos : Vector3, block : int, aux : int, a : float, b : float):
	# Based on MCPE code
	# (Not the best place of inspiration imo)
	var C_ONE_PIXEL : float = 1.0 / 16.0
	var C_HALF_TILE : float = 1.0 / 2.0
	var C_UNK_1 : float = 0.375 # How much to tilt the TOP in relation to the SIDES
	
	var x1 : float = pos.x + 0.5 # Center
	var z1 : float = pos.z + 0.5
	var z2 : float = z1 + b * C_UNK_1 # Torch tilt? (precalculated for some reason)
	var x2 : float = x1 + a * C_UNK_1 # I made x2 precalculated too. 
	# Seems like the decomp wasn't good and decided to do that below.
	
	var x_1 : float = x2 - C_ONE_PIXEL # Also torch tilt?
	var x_2 : float = x2 + C_ONE_PIXEL # OH! Top fire face!
	var x_3 : float = x1 - C_ONE_PIXEL # Small -X side
	var x_4 : float = x1 + C_ONE_PIXEL # Small +X side
	var x_5 : float = x1 - C_HALF_TILE # True -X side
	var x_6 : float = x1 + C_HALF_TILE # True +X side
	var x_7 : float = x_6 + a # Tilted +X side
	var x_8 : float = x_3 + a # Tilted small -X side
	var x_9 : float = x_4 + a # Tilted small +X side
	var x_0 : float = x_5 + a # Tilted -X side
	
	var y_1 = pos.y + C_ONE_PIXEL * 10.0 # Torch height
	var y_2 = pos.y + 1.0 # Texture top
	var y_3 = pos.y + 0.0 # Texture bottom
	
	var z_1 = z2 - C_ONE_PIXEL # Top fire face
	var z_2 = z2 + C_ONE_PIXEL
	var z_3 = z1 - C_HALF_TILE # True +-Z side
	var z_4 = z1 + C_HALF_TILE
	var z_5 = z1 - C_ONE_PIXEL # Small +-Z side
	var z_6 = z1 + C_ONE_PIXEL
	var z_7 = z_3 + b # Tilted -Z side
	var z_8 = z_4 + b # Tilted +Z side
	var z_9 = z_5 + b # Tilted small -Z side
	var z_0 = z_6 + b # Tilted small +Z side
	
	# Top
	set_uv_bounds(Vector2(7, 6), Vector2(9, 8))
	construct_face_directly(
		Vector3(x_1, y_1, z_1),
		Vector3(x_2, y_1, z_1),
		Vector3(x_1, y_1, z_2),
		block, aux, 1
	)
	
	reset_uv_bounds()
	# Sides
	construct_face_directly(
		Vector3(x_3, y_2, z_3),
		Vector3(x_3, y_2, z_4),
		Vector3(x_8, y_3, z_7),
		block, aux, 1
	)
	construct_face_directly(
		Vector3(x_4, y_2, z_4),
		Vector3(x_4, y_2, z_3),
		Vector3(x_9, y_3, z_8),
		block, aux, 1
	)
	construct_face_directly(
		Vector3(x_5, y_2, z_6),
		Vector3(x_6, y_2, z_6),
		Vector3(x_0, y_3, z_0),
		block, aux, 1
	)
	construct_face_directly(
		Vector3(x_6, y_2, z_5),
		Vector3(x_5, y_2, z_5),
		Vector3(x_7, y_3, z_9),
		block, aux, 1
	)

func build_mesh():
	reset_buffers()
	var multimesh_instance = MultiMeshInstance3D.new()
	var multimesh = MultiMesh.new()
	var water_multimesh_instance = MultiMeshInstance3D.new()
	var water_multimesh = MultiMesh.new()
	var quad = QuadMesh.new()
	quad.center_offset = Vector3(0.5, 0.5, 0.0)
	quad.material = chunk_material
	#quad.flip_faces = true # This breaks lighting somehow
	multimesh.mesh = quad
	
	var water_quad = QuadMesh.new()
	water_quad.center_offset = Vector3(0.5, 0.5, 0.0)
	water_quad.material = chunk_water_material
	water_multimesh.mesh = water_quad
	
	var cursor = 0
	var x_chunk_offset = chunk_offset.x * 16
	var z_chunk_offset = chunk_offset.y * 16
	# Only build +x, +y, +z faces.
	for x_offset in 16:
		var x = x_offset + x_chunk_offset
		for z_offset in 16:
			var z = z_offset + z_chunk_offset
			cursor = coords_to_offset(x, 0, z)
			for y in 128:
				var pos = Vector3(x, y, z)
				var block = block_ids[cursor]
				var aux = get_aux_from_cursor(cursor)
				
				if is_block_transparent(block):
					# Build faces inwards
					if (x != 255) and not is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, NegX, pos + Vector3(1,0,0), block_ids[cursor + step_x], get_aux_from_cursor(cursor + step_x), 2)
					if (y != 127) and not is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, NegY, pos + Vector3(0,1,0), block_ids[cursor + step_y], get_aux_from_cursor(cursor + step_y), 0)
					if (z != 255) and not is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, NegZ, pos + Vector3(0,0,1), block_ids[cursor + step_z], get_aux_from_cursor(cursor + step_z), 4)
					
					if block != 0:
						# Custom block building
						match BlockUtils.get_block_shape(block):
							0:
								# Outwards faces
								if (y != 127) and block_ids[cursor + step_y] != block and is_block_transparent(block_ids[cursor + step_y]):
									construct_face(cube_v_set, PosY, pos, block, aux, 1)
								if (x != 255) and block_ids[cursor + step_x] != block and is_block_transparent(block_ids[cursor + step_x]):
									construct_face(cube_v_set, PosX, pos, block, aux, 3)
								if (z != 255) and block_ids[cursor + step_z] != block and is_block_transparent(block_ids[cursor + step_z]):
									construct_face(cube_v_set, PosZ, pos, block, aux, 5)
								# Inwards faces
								if (y != 0) and block_ids[cursor - step_y] != block and is_block_transparent(block_ids[cursor - step_y]):
									construct_face(cube_v_set, NegY, pos, block, aux, 0)
								if (x != 0) and block_ids[cursor - step_x] != block and is_block_transparent(block_ids[cursor - step_x]):
									construct_face(cube_v_set, NegX, pos, block, aux, 2)
								if (z != 0) and block_ids[cursor - step_z] != block and is_block_transparent(block_ids[cursor - step_z]):
									construct_face(cube_v_set, NegZ, pos, block, aux, 4)
							1:
								# Cross
								if block == 31 and aux != 0: # Grass
									set_color(32, 255, 16)
								construct_face(cube_v_set, [2, 7, 0, 5], pos, block, aux, 1)
								construct_face(cube_v_set, [7, 2, 5, 0], pos, block, aux, 1)
								construct_face(cube_v_set, [3, 6, 1, 4], pos, block, aux, 1)
								construct_face(cube_v_set, [6, 3, 4, 1], pos, block, aux, 1)
								reset_color()
							2:
								# Torch
								match aux:
									1:
										render_shape_torch(pos + Vector3(-0.1, 0.2, 0), block, aux, -0.4, 0.0)
										#tesselateTorch(tile, float(x) - 0.1f, float(y) + 0.2f, float(z), -0.4f, 0.0f)
									2:
										render_shape_torch(pos + Vector3(0.1, 0.2, 0), block, aux, 0.4, 0.0)
										#tesselateTorch(tile, float(x) + 0.1f, float(y) + 0.2f, float(z), 0.4f, 0.0f)
									3:
										render_shape_torch(pos + Vector3(0, 0.2, -0.1), block, aux, 0.0, -0.4)
										#tesselateTorch(tile, float(x), float(y) + 0.2f, float(z) - 0.1f, 0.0f, -0.4f)
									4:
										render_shape_torch(pos + Vector3(0, 0.2, 0.1), block, aux, 0.0, 0.4)
										#tesselateTorch(tile, float(x), float(y) + 0.2f, float(z) + 0.1f, 0.0f, 0.4f)
									_:
										render_shape_torch(pos, block, aux, 0.0, 0.0)
										#tesselateTorch(tile, float(x), float(y), float(z), 0.0f, 0.0f)
							3:
								# Fire
								pass
							4:
								# Water
								if (pos.y != 127) and BlockUtils.is_water(block_ids[cursor + step_y]):
									# Skip processing water under water (-18ms/c)
									render_shape_triangulated_cube(cube_v_set, pos, cursor, block, aux)
								else:
									#print(chunk_handler.get_water_height(pos))
									var height_a = chunk_handler.get_water_height(pos)
									var height_b = chunk_handler.get_water_height(pos + Vector3(0,0,1))
									var height_c = chunk_handler.get_water_height(pos + Vector3(1,0,0))
									var height_d = chunk_handler.get_water_height(pos + Vector3(1,0,1))
									var water_v_set : PackedVector3Array = [
										Vector3(0,0,0),
										Vector3(0,0,1),
										Vector3(0,height_a,0),
										Vector3(0,height_b,1),
										Vector3(1,0,0),
										Vector3(1,0,1),
										Vector3(1,height_c,0),
										Vector3(1,height_d,1)
									]
									render_shape_triangulated_cube(water_v_set, pos, cursor, block, aux)
							5:
								# Slab
								if aux < 8:
									# Bottom
									set_uv_bounds(Vector2(0, 8), Vector2(16, 16))
									render_shape_weird_cube(bottom_slab_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,0,0,0,0], false)
									reset_uv_bounds()
									render_shape_weird_cube(bottom_slab_v_set, pos, cursor, block, aux, [0,1,0,0,0,0], [0,0,0,0,0,0], true)
									render_shape_weird_cube(bottom_slab_v_set, pos, cursor, block, aux, [1,0,0,0,0,0], [0,0,0,0,0,0], false)
								else:
									# Top
									set_uv_bounds(Vector2(0, 0), Vector2(16, 8))
									render_shape_weird_cube(top_slab_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,0,0,0,0], false)
									reset_uv_bounds()
									render_shape_weird_cube(top_slab_v_set, pos, cursor, block, aux, [0,1,0,0,0,0], [0,0,0,0,0,0], true)
									render_shape_weird_cube(top_slab_v_set, pos, cursor, block, aux, [1,0,0,0,0,0], [0,0,0,0,0,0], false)
							6:
								# Crops
								pos -= Vector3(0,1,0) / 16.0
								render_shape_weird_cube(farmland_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,4,4,4,4], true)
								render_shape_weird_cube(farmland_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,12,12,12,12], true)
							11:
								# Fence 
								#render_shape_pixel_consistent_cube(Vector3(6,7,8), Vector3(13,15,14), pos, block, aux)
								# Center
								render_shape_pixel_consistent_cube(Vector3(6,0,6), Vector3(10,16,10), pos, block, aux)
								if (x != 0) and BlockUtils.does_connect_to_fences(block_ids[cursor - step_x]):
									render_shape_pixel_consistent_cube(Vector3(0,6,7), Vector3(6,9,9), pos, block, aux)
									render_shape_pixel_consistent_cube(Vector3(0,12,7), Vector3(6,15,9), pos, block, aux)
								if (x != 255) and BlockUtils.does_connect_to_fences(block_ids[cursor + step_x]):
									render_shape_pixel_consistent_cube(Vector3(10,6,7), Vector3(16,9,9), pos, block, aux)
									render_shape_pixel_consistent_cube(Vector3(10,12,7), Vector3(16,15,9), pos, block, aux)
								if (z != 0) and BlockUtils.does_connect_to_fences(block_ids[cursor - step_z]):
									render_shape_pixel_consistent_cube(Vector3(7,6,0), Vector3(9,9,6), pos, block, aux)
									render_shape_pixel_consistent_cube(Vector3(7,12,0), Vector3(9,15,6), pos, block, aux)
								if (z != 255) and BlockUtils.does_connect_to_fences(block_ids[cursor + step_z]):
									render_shape_pixel_consistent_cube(Vector3(7,6,10), Vector3(9,9,16), pos, block, aux)
									render_shape_pixel_consistent_cube(Vector3(7,12,10), Vector3(9,15,16), pos, block, aux)
								
								#set_uv_bounds(Vector2(6, 0), Vector2(10, 16))
								#render_shape_weird_cube(fence_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,0,0,0,0], false)
								#reset_uv_bounds()
								#set_uv_bounds(Vector2(6,6), Vector2(10, 10))
								#render_shape_weird_cube(fence_v_set, pos, cursor, block, aux, [1,1,0,0,0,0], [0,0,0,0,0,0], false)
								#reset_uv_bounds()
								# render_shape_weird_cube()
							12:
								# Farmland
								# Sides
								set_uv_bounds(Vector2(0,0), Vector2(16, 15))
								render_shape_weird_cube(farmland_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,0,0,0,0], false)
								reset_uv_bounds()
								# Top
								render_shape_weird_cube(farmland_v_set, pos, cursor, block, aux, [1,0,0,0,0,0], [0,0,0,0,0,0], true)
								# Bottom
								render_shape_weird_cube(farmland_v_set, pos, cursor, block, aux, [0,1,0,0,0,0], [0,0,0,0,0,0], false)
							13:
								# For cacti just move the faces like a lazy bun
								render_shape_weird_cube(cube_v_set, pos, cursor, block, aux, [1,1,1,1,1,1], [0,0,1,1,1,1], true)
							17:
								# Snow
								set_uv_bounds(Vector2(0,0), Vector2(16, 2))
								render_shape_weird_cube(snow_v_set, pos, cursor, block, aux, [0,0,1,1,1,1], [0,0,0,0,0,0], false)
								reset_uv_bounds()
								render_shape_weird_cube(snow_v_set, pos, cursor, block, aux, [1,1,0,0,0,0], [0,0,0,0,0,0], false)
				else:
					# Build faces outwards
					if (x == 255) or is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, PosX, pos, block, aux, 3)
					if (y == 127) or is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, PosY, pos, block, aux, 1)
					if (z == 255) or is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, PosZ, pos, block, aux, 5)
				cursor += 1

	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = len(transform_array)
	multimesh.visible_instance_count = len(transform_array)
	for i in len(transform_array):
		multimesh.set_instance_transform(i, transform_array[i])
		multimesh.set_instance_custom_data(i, pack_data_to_color(i))
	
	water_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	water_multimesh.use_custom_data = true
	water_multimesh.instance_count = len(water_transform_array)
	water_multimesh.visible_instance_count = len(water_transform_array)
	print("Water L:", len(water_transform_array))
	for i in len(water_transform_array):
		water_multimesh.set_instance_transform(i, water_transform_array[i])
		water_multimesh.set_instance_custom_data(i, Color(0, uv_water_array[i], 0, 0))
	
	multimesh_instance.multimesh = multimesh
	water_multimesh_instance.multimesh = water_multimesh
	
	for child in get_children():
		if child is MultiMeshInstance3D:
			child.queue_free()
			#print("Free child")
	
	add_child(water_multimesh_instance)
	add_child(multimesh_instance)
	#multimesh_instance.position = -chunk_offset * 16
	
func get_aux_from_cursor(cursor : int):
	return block_aux[cursor >> 1] >> 4 if (cursor % 2) else block_aux[cursor >> 1] & 15

func coords_to_offset(x : int, y : int, z : int):
	return (((x & 0xff) << 15) + ((z & 0xff) << 7) + (y & 0x7f))
	# Backwards order:      yyyyyyyzzzzzzzzxxxxxxxx
	# Old (in chunk) order: yyyyyyyzzzzxxxx
