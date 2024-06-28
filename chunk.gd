extends Node3D
# Mesher based on https://github.com/xen-42/Minecraft-Clone/blob/dd4e4e898864ed7e841a7336cd5f8b3f7e0de04f/Chunk.gd

@export var chunk_material : Material
var block_ids : PackedByteArray = []
var block_aux : PackedByteArray = []
var loaded : bool = false
var uv_map_function

const step_x = 1 << 11
const step_y = 1
const step_z = 1 << 7

func _ready():
	# Get uv mapper from chunk handler
	uv_map_function = get_parent().block_to_texture

func setup_from_data(blocks : PackedByteArray, data : PackedByteArray):
	block_ids = blocks
	block_aux = data
	loaded = true
	build_mesh()

func update_block(pos : Vector3, block : int, data : int):
	if loaded:
		pass

func place_block(pos : Vector3, block : int, data : int, face : Vector3):
	if loaded:
		pass

func remove_block(pos : Vector3):
	if loaded:
		pass

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
var transform_array = []
var uv_array = []

func construct_face(vertex_set : PackedVector3Array, face_data : PackedByteArray, pos : Vector3, block : int, aux : int, side : int):
	var a = pos + vertex_set[face_data[0]]
	var b = pos + vertex_set[face_data[1]]
	var c = pos + vertex_set[face_data[2]]
	#var d = pos + vertex_set[face_data[3]]
	
	#var uv_a = (uv + uv_offset[0]) / atlas_size
	#var uv_b = (uv + uv_offset[1]) / atlas_size
	#var uv_c = (uv + uv_offset[2]) / atlas_size
	#var uv_d = (uv + uv_offset[3]) / atlas_size
	# This breaks lighting somehow ( C -> B )
	transform_array.append(Transform3D(c - a, b - a, (c - a).cross(b - a), a)) # Magic sauce
	uv_array.append(uv_map_function.call(block, aux, side))
	#visual_surface.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c], [], [], [normal, normal, normal])
	#visual_surface.add_triangle_fan([b, d, c], [uv_b, uv_d, uv_c], [], [], [normal, normal, normal])
	
	#if collision_enabled:
	#	pass
		#collision_surface.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c])
		#collision_surface.add_triangle_fan([b, d, c], [uv_b, uv_d, uv_c])

func is_block_transparent(id : int):
	return id == 0

func build_mesh():
	transform_array = []
	uv_array = []
	var mesh = ArrayMesh.new()
	var mesh_instance = MeshInstance3D.new()
	var multimesh_instance = MultiMeshInstance3D.new()
	var multimesh = MultiMesh.new()
	var quad = QuadMesh.new()
	quad.center_offset = Vector3(0.5, 0.5, 0.0)
	quad.material = chunk_material
	#quad.flip_faces = true # This breaks lighting somehow
	multimesh.mesh = quad
	
	var cursor = 0
	visual_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Only build +x, +y, +z faces.
	for x in 16:
		for z in 16:
			for y in 128:
				var pos = Vector3(x, y, z)
				var block = block_ids[cursor]
				var aux = get_aux_from_cursor(cursor)
				
				var is_solid = true
				if is_block_transparent(block):
					# Build faces inwards
					if (x != 15) and not is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, NegX, pos + Vector3(1,0,0), block_ids[cursor + step_x], get_aux_from_cursor(cursor + step_x), 2)
					if (y != 127) and not is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, NegY, pos + Vector3(0,1,0), block_ids[cursor + step_y], get_aux_from_cursor(cursor + step_y), 0)
					if (z != 15) and not is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, NegZ, pos + Vector3(0,0,1), block_ids[cursor + step_z], get_aux_from_cursor(cursor + step_z), 4)
				else:
					# Build faces outwards
					if (x == 15) or is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, PosX, pos, block, aux, 3)
					if (y == 127) or is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, PosY, pos, block, aux, 1)
					if (z == 15) or is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, PosZ, pos, block, aux, 5)
				
				cursor += 1
	
	# Negative x wall
	cursor = 0
	for z in 16:
		for y in 128:
			var block = block_ids[cursor]
			var is_transparent = is_block_transparent(block)
			var is_solid = true
			if not is_transparent:
				construct_face(cube_v_set, NegX, Vector3(0, y, z), block, get_aux_from_cursor(cursor), 3)
			cursor += 1
	
	# Negative z wall
	cursor = 0
	for x in 16:
		for y in 128:
			var block = block_ids[cursor]
			var is_transparent = is_block_transparent(block)
			var is_solid = true
			if not is_transparent:
				construct_face(cube_v_set, NegZ, Vector3(x, y, 0), block, get_aux_from_cursor(cursor), 5)
			cursor += 1
		cursor += step_x - 128
	visual_surface.commit(mesh)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = chunk_material
	
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = len(transform_array)
	multimesh.visible_instance_count = len(transform_array)
	for i in len(transform_array):
		multimesh.set_instance_transform(i, transform_array[i])
		multimesh.set_instance_custom_data(i, Color(1.0, 1.0, 1.0, uv_array[i]))
	
	multimesh_instance.multimesh = multimesh
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
		if child is MultiMeshInstance3D:
			child.queue_free()
	add_child(mesh_instance)
	add_child(multimesh_instance)
	
func get_aux_from_cursor(cursor : int):
	return block_aux[cursor / 2] >> 4 if (cursor % 2) else block_aux[cursor / 2] & 15

static func coords_to_offset(x : int, y : int, z : int):
	return (((x & 0x0f) << 11) + ((z & 0x0f) << 7) + (y & 0x7f))
