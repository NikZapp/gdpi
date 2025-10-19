extends CharacterBody3D

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
@onready var camera = $Camera
@onready var debug_menu = $UI/Debug
@onready var collision_node = $Collisions
@onready var hitbox = $Hitbox

@export var chunk_handler_path : NodePath
@export var chat_handler_path : NodePath
@onready var chunk_handler : Node = get_node(chunk_handler_path)
@onready var chat_handler : Node = get_node(chat_handler_path)

# Movement
var normal_movement = false
var is_sprinting = false
var is_sneaking = false
var collision_shapes = {}
var movement = Vector3(0, 0, 0) # What you are inputting (joystick/keyboard)
var motion = Vector3(0, 0, 0) # Actual motion

# Server position syncronisation
var old_pos = Vector3()
var old_rotation = Vector3()
var id = -1

# Login process
var logged_in : bool = false

# F3 screen
var debug_module_data : Dictionary = {}

# Chat
var is_chat_open : bool = false

# Menus
var current_menu_path : Array = []

func _ready():
	add_debug_module("menu_path")
	
	add_debug_module("freecam_speed")
	add_debug_module("pos_rot_display")
	add_debug_module("performance_fps")
	
	create_collision_shapes()
	
	network_handler.received_packet_decoded.connect(_on_packet)
	raknet.connect(Global.ip, Global.port)
	login(Global.username)


func _process(delta):
	set_debug_module_text("menu_path", "menu path: " + str(current_menu_path))
	
	update_server_position()
	update_debug_menu()


func _physics_process(delta: float) -> void:
	if normal_movement:
		update_movement(delta)
	else:
		motion = Vector3(0, 0, 0)
	update_collision_shapes()
	hitbox.disabled = !normal_movement


func _on_packet(packet : Dictionary):
	match packet.packet_name:
		"StartGamePacket":
			id = packet.entity_id
			position = Vector3(packet.x, packet.y, packet.z)
			logged_in = true
		"LoginStatusPacket":
			chat_handler.add_chat_log("[b]Login status {0}[/b]\n".format(packet.status))
			if packet.status != 0:
				chat_handler.add_chat_log("[b][color=red]Invalid login status![/color][/b]\n")
				#print("Invalid login status!")
				match packet.status:
					1:
						chat_handler.add_chat_log("[b][color=red]Outdated client[/color][/b]\n")
						#print("Outdated client")
					2:
						chat_handler.add_chat_log("[b][color=red]Outdated server[/color][/b]\n")
						#print("Outdated server")
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
	chat_handler.add_chat_log("[b]Logging in as {0}[/b]\n".format([username]))


func logout():
	raknet.shutdown()


func open_chat():
	if len(current_menu_path) != 0 and current_menu_path[-1] == "chat":
		return is_chat_open
	current_menu_path.append("chat")
	is_chat_open = chat_handler.open_chat()
	return is_chat_open


func close_chat():
	if len(current_menu_path) != 0 and current_menu_path[-1] == "chat":
		current_menu_path.pop_back()
		is_chat_open = chat_handler.close_chat()
	return is_chat_open


func send_chat():
	if len(current_menu_path) != 0 and current_menu_path[-1] == "chat":
		current_menu_path.pop_back()
		is_chat_open = chat_handler.send_chat()
	return is_chat_open


func _exit_tree():
	chat_handler.add_chat_log("[b]Logout[/b]\n")
	#print("Logout")
	logout()


func screenshot(filename : String) -> void:
	var user_folder = DirAccess.open("user://")
	user_folder.make_dir("screenshots")
	
	var screen_image = get_viewport().get_texture().get_image()
	var full_filename = "user://screenshots/" + str(filename) + ".png"
	screen_image.save_png(full_filename)
	chat_handler.add_chat_log("Saved screenshot to {0}".format([ProjectSettings.globalize_path(full_filename)]))


func set_debug_menu_visibility(_visible : bool) -> void:
	debug_menu.visible = _visible


func get_debug_menu_visibility() -> bool:
	return debug_menu.visible


func enable_normal_movement() -> void:
	normal_movement = true


func disable_normal_movement() -> void:
	normal_movement = false


func jump():
	if is_on_floor():
		motion.y = 0.42


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


func create_collision_shapes():
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in range(-1, 3):
				var box = CollisionShape3D.new()
				var box_shape = BoxShape3D.new()
				box.shape = box_shape
				box.position = Vector3(-10, -10, -10)
				collision_node.add_child(box)
				collision_shapes[Vector3(dx, dy, dz)] = box


func update_collision_shapes():
	var pos = floor(position)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in range(-1, 3):
				var offset = Vector3(dx, dy, dz)
				var check_pos = pos + offset
				var block = chunk_handler.get_block(check_pos)
				
				if BlockUtils.has_collision(block):
					var collision_aabb : AABB = chunk_handler.get_collision_aabb(check_pos)
					collision_shapes[offset].position = collision_aabb.position
					collision_shapes[offset].shape.size = collision_aabb.size
				else:
					collision_shapes[offset].position = Vector3(-10, -10, -10) # Disable kinda


func update_movement(delta):
	if is_sneaking:
		movement.x *= 0.3
		movement.z *= 0.3
	var ticks = delta * 20.0
	
	movement.x *= pow(0.98, ticks) # Per tick
	movement.z *= pow(0.98, ticks) # Per tick
	
	var mult : float = 0.91
	if is_on_floor():
		var floor_block = chunk_handler.get_block(floor(position - Vector3(0,1,0)))
		mult *= BlockUtils.get_block_slipperiness(floor_block)
	
	var accel : float = (0.6*0.91)**3 / (mult * mult * mult)
	
	var movement_factor : float = 0.1 if is_on_floor() else 0.02
	movement_factor *= 1.3 if is_sprinting else 1.0
	
	movement_factor *= ticks # Account for physics tickrate
	update_motion_xz(movement.x, movement.z, movement_factor)
	
	#this.moveEntity(this.motionX, this.motionY, this.motionZ);
	velocity = motion * 20.0
	move_and_slide()
	motion = velocity / 20.0
	
	# PER TICK?!??!
	# WWWWWWHHHHHHHHHHYYYYYYYYYYYYYY
	# words cannot describe how much pain i went through to convert per tick gravity with drag to delta based
	var a = -0.08 # Gravity
	var m = 0.98 # Drag
	var v_max = (a * m) / (1.0 - m) # Terminal velocity
	var v = motion.y # Current velocity
	motion.y += (v_max - v) * (1.0 - pow(m, ticks))
	# TODO: integrate this maybe?
	# velocity is correct now, but position isnt matching (v <= v_real)
	# for that it must be integrated instead

	motion.x *= pow(mult, ticks);
	motion.z *= pow(mult, ticks);


func update_motion_xz(strafe : float, forward : float, movement_factor : float):
	var distance_sq = strafe * strafe + forward * forward
	if distance_sq >= 0.0001:
		var distance = min(1.0, sqrt(distance_sq)) # Clamp at 1 max
		
		distance = movement_factor / distance # What?
		strafe *= distance
		forward *= distance
		var sin_yaw : float = -sin(camera.rotation.y)
		var cos_yaw : float = cos(camera.rotation.y)
		motion.x += strafe * cos_yaw - forward * sin_yaw
		motion.z += strafe * sin_yaw + forward * cos_yaw
		
