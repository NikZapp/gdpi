shader_type spatial;
render_mode unshaded, cull_disabled;
// 8 bytes per face
// XXXXXXXX YYYYYYYY ZZZZZZZZ XYYYYZxx yyzzSSss DDDDDDDD UUUUVVVV --------
// my dog took a bite.

uniform usampler2D mesh_data;
uniform sampler2D atlas;
uniform float k__;

float weight(float a, float b) { 
	return max(0.0, 1.0 - abs(a - b));
}

vec3 branchless_select4(vec3 a, vec3 b, vec3 c, vec3 d, float k) {
	return 
		weight(0.0, k) * a + 
		weight(1.0, k) * b + 
		weight(2.0, k) * c + 
		weight(3.0, k) * d; 
}

void vertex() {
	int face_id = (VERTEX_ID / 6);
	int vertex_n = min(3, VERTEX_ID % 6);
	
	uint value_a = texelFetch(mesh_data, ivec2(face_id * 2, 0), 0).r;
	uint value_b = texelFetch(mesh_data, ivec2(face_id * 2 + 1, 0), 0).r;
	uint origin_x = 
	(((value_a >> uint(31)) & uint(1)) << uint(8)) | // High extension
	((value_a >> uint(0)) & uint(0xff));             // Low value
	uint origin_y = 
	(((value_a >> uint(27)) & uint(15)) << uint(8)) | // High extension
	((value_a >> uint(8)) & uint(0xff));              // Low value
	uint origin_z = 
	(((value_a >> uint(20)) & uint(1)) << uint(8)) | // High extension
	((value_a >> uint(16)) & uint(0xff));            // Low value
	
	vec3 origin = vec3(uvec3(origin_x, origin_y, origin_z)) / 16.0;
}

int bool_to_sign(bool v) {
	return int(v) * 2 - 1;
}

void fragment() {
	uint value_a = texelFetch(mesh_data, ivec2(0, 0), 0).r;
	uint value_b = texelFetch(mesh_data, ivec2(1, 0), 0).r;
	uint origin_x = 
	(((value_a >> 31u) & 1u) << 8u) | // High extension
	((value_a >> 0u) & 0xffu);        // Low value
	uint origin_y = 
	(((value_a >> 27u) & 15u) << 8u) | // High extension
	((value_a >> 8u) & 0xffu);         // Low value
	uint origin_z = 
	(((value_a >> 26u) & 1u) << 8u) | // High extension
	((value_a >> 16u) & 0xffu);       // Low value
	
	bool x_changed_in_a = bool((value_a >> 25u) & 1u);
	bool x_changed_in_b = bool((value_a >> 24u) & 1u);
	bool y_changed_in_a = bool((value_b >> 7u) & 1u);
	bool y_changed_in_b = bool((value_b >> 6u) & 1u);
	bool z_changed_in_a = bool((value_b >> 5u) & 1u);
	bool z_changed_in_b = bool((value_b >> 4u) & 1u);
	
	vec3 direction_mask_a_first = vec3(bvec3(
		x_changed_in_a,
		y_changed_in_a,
		z_changed_in_a
	));
	float two_changed_in_a = step(1.5, dot(direction_mask_a_first, vec3(1)));
	
	vec3 direction_mask_b = vec3(bvec3(
		x_changed_in_b,
		y_changed_in_b,
		z_changed_in_b
	));
	
	bool sign_first_in_a = bool((value_b >> 3u) & 1u);
	bool sign_first_in_b = bool((value_b >> 2u) & 1u);
	bool sign_second_in_a = bool((value_b >> 1u) & 1u);
	bool sign_second_in_b = bool(value_b & 1u);
	
	int delta_first_a = (int((value_b >> 12u) & 15u) + 1) * bool_to_sign(sign_first_in_a);
	int delta_first_b = (int((value_b >> 12u) & 15u) + 1) * bool_to_sign(sign_first_in_b);
	int delta_second_a = (int((value_b >> 8u) & 15u) + 1) * bool_to_sign(sign_second_in_a);
	int delta_second_b = (int((value_b >> 8u) & 15u) + 1) * bool_to_sign(sign_second_in_b);
	
	int uv = int(value_b >> 16u);
	
	float a = float((value_b >> 12u) & 1u);
	ALBEDO = vec3(a, a, mod(UV.y * 64.0, 1.0));
}