extends VBoxContainer

@onready var peer = PacketPeerUDP.new()
const magic = "00ffff00fefefefefdfdfdfd12345678"
var servers = {}
var server_template = preload("res://scenes/ui/server_list_item.tscn")
@onready var ping_thread_running = true
@onready var ping_thread = Thread.new()

@onready var line_edit_ip: LineEdit = $"../../Options/GridContainer/LineEditIP"
@onready var line_edit_port: LineEdit = $"../../Options/GridContainer/LineEditPort"

func _ready() -> void:
	ping_thread.start(packet_process_thread, Thread.PRIORITY_HIGH)
	
	peer.set_broadcast_enabled(true)
	peer.set_dest_address("255.255.255.255", 19132)
	
	peer.bind(19132)
	
	
	refresh_local_servers()

func process_packets() -> void:
	var packet = peer.get_packet()
	var server_addr = peer.get_packet_ip() + ":" + str(peer.get_packet_port())
	
	if peer.get_packet_error() == OK and len(packet) != 0 and packet[0] == 0x1c:
		add_server(server_addr, packet)

func packet_process_thread() -> void:
	while ping_thread_running:
		if peer.get_available_packet_count() > 0:
			process_packets()

func refresh_local_servers() -> void:
	clear_servers()
	var packet : PackedByteArray = [2] # Ping packet
	
	packet.resize(9)
	packet.append_array(magic.hex_decode())
	
	var current_time = Time.get_ticks_msec()
	packet.encode_u64(1, current_time)
	
	peer.put_packet(packet)

func clear_servers():
	for child in get_children():
		child.queue_free()
	servers = {}

func add_server(address : String, packet : PackedByteArray) -> void:
	var server
	if address in servers.keys():
		server = servers[address]
	else:
		server = server_template.instantiate()
	var ping = Time.get_ticks_msec() - packet.decode_u64(1)
	server.name = address
	call_deferred("add_child", server)
	servers[address] = server
	server.call_deferred("setup", address, packet, ping)

func _on_button_refresh_pressed() -> void:
	refresh_local_servers()

func _exit_tree() -> void:
	peer.close()
	ping_thread_running = false
	ping_thread.wait_to_finish()

func set_server(ip, port) -> void:
	line_edit_ip.text = ip
	line_edit_port.text = str(port)
