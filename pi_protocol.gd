extends Object
static var protocol_path = "res://pi_protocol/pi_protocol/data/protocol.json"
static var name_to_id : Dictionary
static var packet_data : Dictionary

static var encoded_packet : PackedByteArray = []

enum MetadataType {BYTE, SHORT, INT, FLOAT, STRING, ITEM, VECTOR}

static func load_protocol() -> void:
	encoded_packet.resize(64)
	var data = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	for packet_name in data:
		var packet_info = data[packet_name]
		var packet_id = int(packet_info["id"])
		name_to_id[packet_name] = packet_id
		packet_data[packet_id] = {
			"packet_id": packet_id,
			"packet_name": packet_name,
			"fields": {}
		}
		# TODO: Profile if reversing the PackedByteArray is faster than reading
		# it with a custom function.
		for field in packet_info["fields"].keys():
			var field_type = packet_info["fields"][field]
			packet_data[packet_id]["fields"][field.to_snake_case()] = field_type
	print(packet_data)
	
	

static func decode(data : PackedByteArray):
	if data.size() == 0:
		return {
			"packet_name": "EmptyPacket",
			"packet_id": -1
		}
		
	var packet_template = packet_data.get(data[0])
	if (!packet_template):
		return {
			"packet_name": "UnknownPacket",
			"packet_id": data[0],
			"data": data
		}
	
	var decoded_packet = {
		"packet_name": packet_template["packet_name"],
		"packet_id": packet_template["packet_id"]
	}
	
	var cursor = 1
	for field_name in packet_template["fields"].keys():
		var field_type = packet_template["fields"][field_name]
		match field_type:
			"Byte":
				decoded_packet[field_name] = data.decode_s8(cursor)
				cursor += 1
			"UnsignedByte":
				decoded_packet[field_name] = data.decode_u8(cursor)
				cursor += 1
			"ShortBE":
				reverse_endianness(data, cursor, 2)
				decoded_packet[field_name] = data.decode_s16(cursor)
				cursor += 2
			"UnsignedShortBE":
				reverse_endianness(data, cursor, 2)
				decoded_packet[field_name] = data.decode_u16(cursor)
				cursor += 2
			"IntBE":
				reverse_endianness(data, cursor, 4)
				decoded_packet[field_name] = data.decode_s32(cursor)
				cursor += 4
			"UnsignedIntBE":
				reverse_endianness(data, cursor, 4)
				decoded_packet[field_name] = data.decode_u32(cursor)
				cursor += 4
			"FloatBE":
				reverse_endianness(data, cursor, 4)
				decoded_packet[field_name] = data.decode_float(cursor)
				cursor += 4
			"UnsignedLongBE":
				reverse_endianness(data, cursor, 8)
				decoded_packet[field_name] = data.decode_u64(cursor)
				cursor += 8
			"String":
				reverse_endianness(data, cursor, 2)
				var length = data.decode_u16(cursor)
				cursor += 2
				var s = ""
				for i in length:
					s += char(data.decode_u8(cursor))
					cursor += 1
				decoded_packet[field_name] = s
			"Item":
				reverse_endianness(data, cursor, 5) # Reverse entire thing
				# Read in reverse too.
				var aux = data.decode_s16(cursor)
				var count = data.decode_u8(cursor + 2)
				var id = data.decode_s16(cursor + 3)
				cursor += 5
				decoded_packet[field_name] = {
					"id": id, 
					"count": count, 
					"aux": aux
				}
			"Metadata":
				# Metadata is special because it uses Little Endian
				var metadata = {}
				while true:
					var id_with_type = data.decode_u8(cursor)
					cursor += 1
					
					if id_with_type == 0x7f:
						break
					
					var id = id_with_type & 0x1f
					var type = id_with_type >> 5
					match type:
						MetadataType.BYTE:
							metadata[id] = [type, data.decode_u8(cursor)]
							cursor += 1
						MetadataType.SHORT:
							metadata[id] = [type, data.decode_s16(cursor)]
							cursor += 2
						MetadataType.INT:
							metadata[id] = [type, data.decode_s32(cursor)]
							cursor += 4
						MetadataType.FLOAT:
							metadata[id] = [type, data.decode_s32(cursor)]
							cursor += 4
						MetadataType.STRING:
							reverse_endianness(data, cursor, 2)
							var length = data.decode_u16(cursor)
							cursor += 2
							var s = ""
							for i in length:
								s += char(data.decode_u8(cursor))
								cursor += 1
							metadata[id] = [type, s]
						MetadataType.ITEM:
							var item_id = data.decode_s16(cursor)
							var count = data.decode_u8(cursor + 2)
							var aux = data.decode_s16(cursor + 3)
							cursor += 5
							metadata[id] = [type, {
								"id": item_id, 
								"count": count, 
								"aux": aux
							}]
						MetadataType.VECTOR:
							var x = data.decode_s32(cursor)
							var y = data.decode_s32(cursor + 4)
							var z = data.decode_s32(cursor + 8)
							cursor += 12
							metadata[id] = [type, Vector3(x, y, z)]
				decoded_packet[field_name] = metadata
			_:
				print("Unknown field type during decoding: ", field_type, " in packet ", packet_template["packet_name"])
		if (field_name == "has_motion") and (decoded_packet.has_motion <= 0):
			return decoded_packet
	return decoded_packet

static func encode(packet_id, data : Dictionary) -> PackedByteArray:
	if typeof(packet_id) == TYPE_STRING:
		packet_id = name_to_id[packet_id]
	var packet_template = packet_data.get(packet_id)
	if (!packet_template):
		var packet : PackedByteArray = [packet_id]
		packet.append_array(data.get("data", PackedByteArray()))
		return packet
	
	# Packing encoding must be forward, because resizing it all the time would
	# be inefficient. Therefore, we only resize at 2^n sizes
	encoded_packet[0] = packet_id
	var cursor = 1
	for field_name in packet_template["fields"].keys():
		if cursor + 16 > encoded_packet.size():
			# Make the shared buffer larger when approaching size limit
			encoded_packet.resize(encoded_packet.size() * 2)
		var field_type = packet_template["fields"][field_name]
		var value = data.get(field_name, 0)
		match field_type:
			"Byte":
				encoded_packet.encode_s8(cursor, value)
				cursor += 1
			"UnsignedByte":
				encoded_packet.encode_u8(cursor, value)
				cursor += 1
			"ShortBE":
				encoded_packet.encode_s16(cursor, value)
				reverse_endianness(encoded_packet, cursor, 2)
				cursor += 2
			"UnsignedShortBE":
				encoded_packet.encode_u16(cursor, value)
				reverse_endianness(encoded_packet, cursor, 2)
				cursor += 2
			"IntBE":
				encoded_packet.encode_s32(cursor, value)
				reverse_endianness(encoded_packet, cursor, 4)
				cursor += 4
			"UnsignedIntBE":
				encoded_packet.encode_u32(cursor, value)
				reverse_endianness(encoded_packet, cursor, 4)
				cursor += 4
			"FloatBE":
				encoded_packet.encode_float(cursor, value)
				reverse_endianness(encoded_packet, cursor, 4)
				cursor += 4
			"UnsignedLongBE":
				encoded_packet.encode_u64(cursor, value)
				reverse_endianness(encoded_packet, cursor, 8)
				cursor += 8
			"String":
				var length = len(value)
				encoded_packet.encode_s16(cursor, length)
				reverse_endianness(encoded_packet, cursor, 2)
				cursor += 2
				var buf = value.to_ascii_buffer()
				for i in length:
					encoded_packet[cursor] = buf[i]
					cursor += 1
			"Item":
				encoded_packet.encode_s16(cursor, value.get("aux", 0))
				encoded_packet.encode_u8(cursor + 2, value.get("count", 1))
				encoded_packet.encode_s16(cursor + 3, value.id)
				reverse_endianness(encoded_packet, cursor, 5)
				cursor += 5
			"Metadata":
				for id in value.keys():
					var type = value[id][0]
					var metadata = value[id][1]
					match type:
						MetadataType.BYTE:
							encoded_packet.encode_u8(cursor, metadata)
							cursor += 1
						MetadataType.SHORT:
							encoded_packet.encode_s16(cursor, metadata)
							cursor += 2
						MetadataType.INT:
							encoded_packet.encode_s32(cursor, metadata)
							cursor += 4
						MetadataType.FLOAT:
							encoded_packet.encode_s32(cursor, metadata)
							cursor += 4
						MetadataType.STRING:
							var length = len(metadata)
							encoded_packet.encode_s16(cursor, length)
							reverse_endianness(encoded_packet, cursor, 2)
							cursor += 2
							var buf = value.to_ascii_buffer()
							for i in length:
								encoded_packet[cursor] = buf[i]
								cursor += 1
						MetadataType.ITEM:
							encoded_packet.encode_s16(cursor, metadata.id)
							encoded_packet.encode_u8(cursor + 2, metadata.get("count", 1))
							encoded_packet.encode_s16(cursor + 3, metadata.get("aux", 0))
							cursor += 5
						MetadataType.VECTOR:
							encoded_packet.encode_s32(cursor, int(metadata.x))
							encoded_packet.encode_s32(cursor + 4, int(metadata.y))
							encoded_packet.encode_s32(cursor + 8, int(metadata.z))
							cursor += 12
				encoded_packet.encode_u8(cursor, 0x7f)
				cursor += 1
			_:
				print("Unknown field type during encoding: ", field_type, " in packet ", packet_template["packet_name"])
	return encoded_packet.slice(0, cursor)

static func to_id(name : String) -> int:
	return name_to_id.get(name, -1)

static func reverse_endianness(buffer : PackedByteArray, start : int, length : int) -> void:
	var temp
	for i in (length >> 1):
		temp = buffer[i + start]
		buffer[i + start] = buffer[length-i-1 + start]
		buffer[length-i-1 + start] = temp
