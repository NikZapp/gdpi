extends Control

@export var network_handler_path : NodePath
@onready var network_handler : Node = get_node(network_handler_path)
@onready var raknet : RakNetConnector = network_handler.raknet
@onready var protocol : Resource = network_handler.protocol

@onready var chat_input : TextEdit = $Chat/Panel/VBoxContainer/HBoxContainer/ChatTextEdit
@onready var chat_log : RichTextLabel = $Chat/Panel/VBoxContainer/ChatRichTextLabel
#@onready var chat_log_b : TextEdit =
var chat_entry = preload("res://scenes/ui/chat/chat_entry.tscn")

var is_chat_open : bool = false

func _ready():
	network_handler.received_packet_decoded.connect(_on_packet)

func _on_packet(packet : Dictionary) -> void:
	match packet.packet_name:
		"MessagePacket":
			#print("MSG ", packet.message)
			add_chat_log(packet.message + "\n")
		"ChatPacket":
			#print("CHAT ", packet.message)
			add_chat_log("[CHAT]" + packet.message + "\n")

func update_visibility():
	$Chat.visible = is_chat_open
	$LiveChat.visible = !is_chat_open


func open_chat():
	is_chat_open = true
	chat_input.grab_focus()
	update_visibility()
	return is_chat_open

func close_chat():
	is_chat_open = false
	update_visibility()
	return is_chat_open

func send_chat():
	is_chat_open = false
	send_message(chat_input.text)
	chat_input.text = ""
	update_visibility()
	return is_chat_open

func add_chat_log(text):
	chat_log.text += text
	var bubble = chat_entry.instantiate()
	bubble.set_text(text)
	$LiveChat.add_child(bubble)

func send_message(message):
	var packet = protocol.encode("ChatPacket", {
		"message": message
	})
	raknet.send(packet)

func _on_send_button_pressed() -> void:
	send_chat()
