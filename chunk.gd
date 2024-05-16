extends Node3D
# Mesher based on https://github.com/xen-42/Minecraft-Clone/blob/dd4e4e898864ed7e841a7336cd5f8b3f7e0de04f/Chunk.gd

var block_ids : PackedByteArray = []
var block_aux : PackedByteArray = []
var loaded : bool = false

const step_x = 1 << 11
const step_y = 1
const step_z = 1 << 7

func _ready():
	pass

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

func construct_face(vertex_set : PackedVector3Array, face_data : PackedByteArray, pos : Vector3, uv : Vector2, collision_enabled : bool):
	var a = pos + vertex_set[face_data[0]]
	var b = pos + vertex_set[face_data[1]]
	var c = pos + vertex_set[face_data[2]]
	var d = pos + vertex_set[face_data[3]]
	
	var uv_a = (uv + uv_offset[0]) / atlas_size
	var uv_b = (uv + uv_offset[1]) / atlas_size
	var uv_c = (uv + uv_offset[2]) / atlas_size
	var uv_d = (uv + uv_offset[3]) / atlas_size
	
	visual_surface.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c])
	visual_surface.add_triangle_fan([b, d, c], [uv_b, uv_d, uv_c])
	
	if collision_enabled:
		pass
		#collision_surface.add_triangle_fan([a, b, c], [uv_a, uv_b, uv_c])
		#collision_surface.add_triangle_fan([b, d, c], [uv_b, uv_d, uv_c])

func is_block_transparent(id : int):
	return id == 0

func build_mesh():
	var mesh = ArrayMesh.new()
	var mesh_instance = MeshInstance3D.new()
	
	var cursor = 0
	visual_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Only build +x, +y, +z faces.
	for x in 16:
		for z in 16:
			for y in 128:
				var pos = Vector3(x, y, z)
				var block = block_ids[cursor]
				
				var is_solid = is_block_transparent(block)
				if is_block_transparent(block):
					# Build faces inwards
					if (x != 15) and not is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, NegX, pos + Vector3(1,0,0), Vector2.ZERO, is_solid)
					if (y != 127) and not is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, NegY, pos + Vector3(0,1,0), Vector2.ZERO, is_solid)
					if (z != 15) and not is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, NegZ, pos + Vector3(0,0,1), Vector2.ZERO, is_solid)
				else:
					# Build faces outwards
					if (x == 15) or is_block_transparent(block_ids[cursor + step_x]):
						construct_face(cube_v_set, PosX, pos, Vector2.ZERO, is_solid)
					if (y == 127) or is_block_transparent(block_ids[cursor + step_y]):
						construct_face(cube_v_set, PosY, pos, Vector2.ZERO, is_solid)
					if (z == 15) or is_block_transparent(block_ids[cursor + step_z]):
						construct_face(cube_v_set, PosZ, pos, Vector2.ZERO, is_solid)
				
				cursor += 1
	
	visual_surface.generate_normals(false)
	visual_surface.commit(mesh)
	mesh_instance.mesh = mesh
	
	
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	add_child(mesh_instance)
