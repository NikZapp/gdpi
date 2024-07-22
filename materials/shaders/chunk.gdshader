shader_type spatial;
render_mode vertex_lighting;
uniform sampler2D block_atlas: source_color;

const float PHI = 1.61803398874989484820459; // Φ = Golden Ratio
float gold_noise(in vec2 xy, in float seed) {
	return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}
varying flat vec4 data;
varying vec3 w_normal;

void vertex() {
	vec2 d = vec2(float(INSTANCE_ID));
	COLOR = vec4(
		gold_noise(d, 1.1),
		gold_noise(d, 1.2),
		gold_noise(d, 1.3),
		1.0
	);
	data = INSTANCE_CUSTOM;
	w_normal = MODEL_NORMAL_MATRIX * NORMAL;
	/*if (dot(NORMAL, vec3(0, -1, 0)) > 0.75) {
		data.a += 1.0;
	}*/

}

void fragment() {
	// Noise to improve visual quality by debanding colors
	float t = mod(TIME, 12.34567);
	vec2 index = SCREEN_UV * (UV + 1.0) * VIEWPORT_SIZE; // Very unreliable on purpose!
	vec3 noise = vec3(
		gold_noise(index, 1.1 + t),
		gold_noise(index, 1.2 + t),
		gold_noise(index, 1.3 + t)
	);

	// Unpack data
	vec3 color_mult = vec3(ivec3(
		int(data.r) >> 8,
		int(data.r) & 0xff,
		int(data.g) >> 8
	)) / 255.0;

	int uv_i = int(round(data.g)) & 0xff;

	vec2 uv_a = vec2(ivec2(
		(int(data.b) >> 12) & 0xf,
		(int(data.b) >>  8) & 0xf
	)) / 16.0;
	vec2 uv_b = vec2(ivec2(
		(int(data.b) >> 4) & 0xf,
		(int(data.b)     ) & 0xf
	) + 1) / 16.0;

	vec2 uv = vec2((1.0 - UV.y), UV.x);
	uv = mix(uv_a, uv_b, uv);

	if (dot(w_normal, vec3(0,-1,0)) > 0.75) uv = uv.yx;
	ivec2 uv_offset = 16 * ivec2(uv_i & 15, (uv_i >> 4));
	vec4 color = texelFetch(block_atlas, uv_offset + ivec2(uv * 16.0), 0);
	ALBEDO = color.rgb * color_mult + noise / 100.0;
	if (color.a < 0.5) discard;

	// Pixelated shadows
	// Only in godot 4.3!
	// As of today (21.07.2024), that requires a beta build.
	// P.S.
	// The position is still a bit weird,
	// I'm still unable to make it work as I want.
	// TODO: Fix this
	///vec3 worldspace_light_pos = LIGHT_VERTEX;
	///worldspace_light_pos = floor(worldspace_light_pos * 16.0) / 16.0;
	///LIGHT_VERTEX = worldspace_light_pos;

}

//void light() {
	//// Called for every pixel for every light affecting the material.
	//// Uncomment to replace the default light processing function with this one.
//}
