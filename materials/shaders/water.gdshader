shader_type spatial;
render_mode vertex_lighting;
uniform sampler2D block_atlas: source_color;

const float PHI = 1.61803398874989484820459; // Φ = Golden Ratio
float gold_noise(in vec2 xy, in float seed) {
	return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}
varying flat vec4 data;
//uniform vec4 input_data;

void vertex() {
	vec2 d = vec2(float(INSTANCE_ID));
	COLOR = vec4(
		gold_noise(d, 1.1),
		gold_noise(d, 1.2),
		gold_noise(d, 1.3),
		1.0
	);
	data = INSTANCE_CUSTOM;
	//data = input_data;
	if (VERTEX_ID == 3) {
		VERTEX = vec3(1.0, 0.0, 0.0);
	}

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
	int uv_i = int(round(data.g)) & 0xff;

	vec2 uv = vec2((1.0 - UV.y), UV.x);
	ivec2 uv_offset = 16 * ivec2(uv_i & 15, (uv_i >> 4));
	vec4 color = texelFetch(block_atlas, uv_offset + ivec2(uv * 16.0), 0);
	ALBEDO = color.rgb + noise / 100.0;
	//if (color.a < 0.5) discard;

	ALPHA = 1.0 * color.a;

	// See chunk.gdshader
	///LIGHT_VERTEX = floor(LIGHT_VERTEX * 16.0) / 16.0;
}

//void light() {
	//// Called for every pixel for every light affecting the material.
	//// Uncomment to replace the default light processing function with this one.
//}
