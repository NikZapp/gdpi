extends Node3D
@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol
@onready var camera = $FreeCamera3D

var old_pos = Vector3()
var old_rotation = Vector3()
var id = -1

var logged_in : bool = false

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)
	raknet.connect("localhost", 19132)
	login("GodotPi")

func _process(delta):
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


func login(username : String):
	var login_packet = protocol.encode("LoginPacket", {
		"username": username,
		"protocol_1": 9,
		"protocol_2": 9,
	})
	raknet.send(login_packet)
