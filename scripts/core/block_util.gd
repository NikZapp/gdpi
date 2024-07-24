class_name BlockUtils
extends RefCounted

static var uv_mapping = PackedByteArray()
static var transparent_blocks = [  0,   6,   8,   9,   10,  11,  18,  20,  26,  30, 
								   31,  37,  38,  39,  40,  44,  50,  51,  53,  54, 
								   59,  60,  63,  64,  65,  67,  68,  71,  78,  81,
								   83,  85,  95,  96, 102, 105, 107, 108, 109, 114,
								   128, 156, 254]
static var transparency_mapping = PackedByteArray()
static var transparent_blocks_shapes = {
	6: 1, 30: 1, 31: 1, 37: 1, 38: 1, 39: 1, 40: 1, 83: 1, # Cross
	50: 2, # Torch
	51: 3, # Fire
	8: 4, 9: 4, 10: 4, 11: 4, # Water
	44: 5, # Slab *
	59: 6, # Wheat
	64: 7, 71: 7, # Door
	65: 8, # Ladder
	54: 9, # Chest *
	53: 10, 67: 10, 108: 10, 109: 10, 114: 10, 128: 10, 156: 10, # Stairs
	85: 11, # Fence
	60: 12, # Farmland *
	81: 13, # Cactus
	26: 14, # Bed
	63: 15, # Sign (floor) *
	68: 16, # Sign (wall) *
	78: 17, # Snow
	102: 18, # Glass pane
	105: 19, # Stem
	96: 20, # Trapdoor *
	107: 21, # Fence gate
	95: 22 # Barrier
}

static func setup() -> void:
	load_uv_mappings("res://assets/data/uv.txt")
	load_transparency_mappings()

static func load_uv_mappings(filepath : String) -> void:
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

static func block_to_texture(id : int, data : int, side : int) -> int:
	return uv_mapping[(id * 16 + data) * 6 + min(5, side)]

static func load_transparency_mappings() -> void:
	transparency_mapping.resize(256*16*6)
	transparency_mapping.fill(0)
	for id in transparent_blocks:
		transparency_mapping[id] = 1

static func is_transparent(id : int) -> bool:
	return bool(transparency_mapping[id])

static func get_block_shape(id : int) -> int:
	return transparent_blocks_shapes.get(id, 0)

static func is_transparent_except_shape(id: int, shape : int) -> bool:
	return is_transparent(id) and get_block_shape(id) != shape

static func does_connect_to_fences(id : int) -> bool:
	return id != 0 and (!is_transparent(id) or (get_block_shape(id) in [11, 21]))

# TODO: set up the materials table
''' 
Material
* Material::air,
* Material::dirt,
* Material::wood,
* Material::stone,
* Material::metal,
* Material::water,
* Material::lava,
* Material::leaves,
* Material::plant,
* Material::sponge,
* Material::cloth,
* Material::fire,
* Material::sand,
* Material::decoration,
* Material::glass,
* Material::explosive,
* Material::coral,
* Material::ice,
* Material::topSnow,
* Material::snow,
* Material::cactus,
* Material::clay,
* Material::vegetable,
* Material::portal,
* Material::cake;
'''

static func is_water(id : int) -> bool:
	return (id == 8) or (id == 9)

static func is_lava(id : int) -> bool:
	return (id == 10) or (id == 11)

static func is_snow(id : int) -> bool:
	return (id == 78) or (id == 80) # Add ice in the mix too maybe?

static func has_collision(id : int) -> bool:
	return id != 0 # TODO: do this properly
