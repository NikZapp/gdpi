shader_type spatial;
render_mode unshaded, alpha_to_coverage_and_one;

void fragment() {
	float a = mod(dot(UV * vec2(3, 2) * vec2(256, 128), vec2(1)) + TIME, 2.0);
	float b = abs(1.0 - a);
	ALPHA = smoothstep(0.4, 0.9, b);
	ALBEDO = vec3(0.5, 1.0, 1.0);
}