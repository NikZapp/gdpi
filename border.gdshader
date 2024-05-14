shader_type spatial;
render_mode unshaded;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 pos;

void vertex() {
	pos = VERTEX + (vec3(256, 128, 256) * 0.5);
}

void fragment() {
	float a = mod(dot(UV * vec2(3, 2) * vec2(256, 128), vec2(1)) + TIME, 2.0);
	float b = abs(1.0 - a);
	ALPHA = pow(1.0 / max(1.0, distance(CAMERA_POSITION_WORLD, pos)), 3.0) * smoothstep(0.4, 0.9, b);
	ALBEDO = vec3(0.5, 1.0, 1.0);
}