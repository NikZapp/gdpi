extends Control

const protocol = preload("res://pi_protocol.gd")
var raknet = RakNetConnector.new()
var pid_to_listid = {}

func _ready():
	raknet.startup()
	raknet.connect("localhost", 19132)
	
	protocol.load_protocol()
	for id in protocol.packet_data:
		pid_to_listid[id] = $PanelContainer/HSplitContainer/PacketSelector.item_count
		$PanelContainer/HSplitContainer/PacketSelector.add_item(str(id) + " " + protocol.packet_data[id]["packet_name"])
	
	$PanelContainer/HSplitContainer/PacketSelector.select(pid_to_listid[147], false)
	$PanelContainer/HSplitContainer/PacketSelector.select(pid_to_listid[167], false)
	var login_packet = protocol.encode("LoginPacket", {
		"username": "GodotPi",
		"protocol_1": 9,
		"protocol_2": 9,
	})
	raknet.send(login_packet)
	
	var success = false
	while true:
		var raw_packet = raknet.receive()
		if (!raw_packet):
			continue
		var packet = protocol.decode(raw_packet)
		
		match packet.packet_name:
			"LoginStatusPacket":
				print("Login status " + str(packet.status))
				if packet.status != 0:
					print("Invalid login status!")
					match packet.status:
						1:
							print("Outdated client")
						2:
							print("Outdated server")
					break
			"StartGamePacket":
				print("Starting game:")
				for i in packet.keys():
					if i not in ["packet_name", "packet_id"]:
						print("- " + i + ": " + str(packet[i]))
				success = true
				break
	if not success:
		print("Failed login!")
	else:
		raknet.send(protocol.encode("ReadyPacket", {
			"status": 1
		}))

func _process(_delta):
	while true:
		var raw_packet = raknet.receive()
		if (!raw_packet):
			break
		var packet = protocol.decode(raw_packet)
		
		if !$PanelContainer/HSplitContainer/PacketSelector.is_selected(pid_to_listid[packet["packet_id"]]):
			$PanelContainer/HSplitContainer/Logger/Console.append_text(str(packet["packet_id"]) + " " + packet["packet_name"] + "\n")
			for i in packet.keys():
				if i not in ["packet_id", "packet_name"]:
					$PanelContainer/HSplitContainer/Logger/Console.append_text("> " + i + " = " + str(packet[i]) + "\n")
	if $PanelContainer/HSplitContainer/Logger/Console.get_line_count() > 1000:
		$PanelContainer/HSplitContainer/Logger/Console.clear()
