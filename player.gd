extends Node3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
@onready var camera = $Camera
@onready var debug_menu = $UI/Debug

@export var chunk_handler_path : NodePath
@onready var chunk_handler : Node = get_node(chunk_handler_path)

var normal_movement = false
var is_sprinting = false
var is_sneaking = false

var old_pos = Vector3()
var old_rotation = Vector3()
var id = -1

var logged_in : bool = false

var debug_module_data : Dictionary = {}

func _ready():
	add_debug_module("freecam_speed")
	add_debug_module("pos_rot_display")
	add_debug_module("performance_fps")
	network_handler.received_packet_decoded.connect(_on_packet)
	raknet.connect("localhost", 19132)
	login("GodotPi")

func _process(delta):
	update_server_position()
	update_debug_menu()

func _on_packet(packet : Dictionary):
	match packet.packet_name:
		"StartGamePacket":
			id = packet.entity_id
			position = Vector3(packet.x, packet.y, packet.z)
			logged_in = true
		"LoginStatusPacket":
			print("Login status " + str(packet.status))
			if packet.status != 0:
				print("Invalid login status!")
				match packet.status:
					1:
						print("Outdated client")
					2:
						print("Outdated server")
			elif not logged_in:
				raknet.send(protocol.encode("ReadyPacket", {
					"status": 1
				}))
				chunk_handler.request_all_chunks()


func login(username : String):
	var login_packet = protocol.encode("LoginPacket", {
		"username": username,
		"protocol_1": 9,
		"protocol_2": 9,
	})
	raknet.send(login_packet)

func logout():
	raknet.shutdown()

func _exit_tree():
	print("Logout")
	logout()

func screenshot(filename : String) -> void:
	var user_folder = DirAccess.open("user://")
	user_folder.make_dir("screenshots")
	
	var screen_image = get_viewport().get_texture().get_image()
	var full_filename = "user://screenshots/" + str(filename) + ".png"
	screen_image.save_png(full_filename)
	print("Saved screenshot to " + ProjectSettings.globalize_path(full_filename))

func set_debug_menu_visibility(_visible : bool) -> void:
	debug_menu.visible = _visible

func get_debug_menu_visibility() -> bool:
	return debug_menu.visible

func enable_normal_movement() -> void:
	normal_movement = true

func disable_normal_movement() -> void:
	normal_movement = false

func jump():
	assert(normal_movement, "Normal movement is disabled, cannot jump")
	# TODO: implement this
	return ERR_PRINTER_ON_FIRE

func move_horisontally(direction : Vector2):
	assert(normal_movement, "Normal movement is disabled, cannot move")
	# TODO: implement this
	return ERR_PRINTER_ON_FIRE

func sprint(sprinting : bool):
	is_sprinting = sprinting

func sneak(sneaking : bool):
	is_sneaking = sneaking

func is_debug_module_enabled(path : String):
	return path in debug_module_data.keys()

func add_debug_module(path : String):
	if not is_debug_module_enabled(path):
		debug_module_data[path] = ""

func remove_debug_module(path : String):
	debug_module_data.erase(path)

func set_debug_module_text(path : String, text : String):
	if is_debug_module_enabled(path):
		debug_module_data[path] = text

func update_debug_menu():
	if debug_menu.visible:
		var full_text = ""
		for module in debug_module_data.keys():
			full_text += debug_module_data[module] + "\n"
		debug_menu.text = full_text

func update_server_position():
	if logged_in:
		if position != old_pos or camera.rotation_degrees != old_rotation:
			var move_packet = protocol.encode("MovePlayerPacket", {
				"entity_id": id,
				"x": position.x,
				"y": position.y,
				"z": position.z,
				"pitch": 180 - camera.rotation_degrees.y,
				"yaw": -camera.rotation_degrees.x # Angry at angle order!!!
			})
			raknet.send(move_packet)
			old_pos = position
			old_rotation = camera.rotation_degrees
