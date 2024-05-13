extends Node

const protocol = preload("res://pi_protocol.gd")
@onready var raknet = RakNetConnector.new()

signal received_packet(data : PackedByteArray)
signal received_packet_decoded(data : Dictionary)

func _ready():
	raknet.startup()
	protocol.load_protocol()

func _process(_delta):
	while true:
		var raw_packet = raknet.receive()
		if (!raw_packet):
			break
		
		received_packet.emit(raw_packet)
		
		var packet = protocol.decode(raw_packet)
		received_packet_decoded.emit(packet)
