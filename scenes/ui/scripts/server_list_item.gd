extends Control

var ip = "localhost"
var port = "19132"

func setup(address : String, packet : PackedByteArray, ping : int):
	var guid = packet.slice(9, 17).hex_encode()
	$PanelContainer/Button/MarginContainer/Address.text = guid + "\n" + address
	
	var data = packet.slice(35).get_string_from_ascii()
	$PanelContainer/Button/MarginContainer/MOTD.text = str(data)
	$PanelContainer/Button/MarginContainer/Ping.text = str(ping) + "ms"
	
	ip = address.split(":")[0]
	port = int(address.split(":")[1])


func _on_button_pressed() -> void:
	get_parent().set_server(ip, port)
