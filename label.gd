extends Label

@onready var peer = PacketPeerUDP.new()
const magic = "00ffff00fefefefefdfdfdfd12345678"
var servers = {}

func _ready() -> void:
	peer.set_broadcast_enabled(true)
	peer.set_dest_address("255.255.255.255", 19132)
	
	peer.bind(19132)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = ""
	var packet = peer.get_packet()
	var server_addr = peer.get_packet_ip() + ":" + str(peer.get_packet_port())
	
	if peer.get_packet_error() == OK:
		servers[server_addr] = packet
	else:
		text += "ERROR " + error_string(peer.get_packet_error()) + "\n"
	display_server_list()

func display_server_list():
	for server_addr in servers.keys():
		text += server_addr + "\n"
		text += str(servers[server_addr]) + "\n"
	
func scan_lan_servers():	
	var packet : PackedByteArray = [2] # Ping packet
	packet.append_array([randi() % 256, 0, 0, 0, 0, 0, 0, 0])
	packet.append_array(magic.hex_decode())
	
	peer.put_packet(packet)

func _on_button_pressed() -> void:
	scan_lan_servers()
