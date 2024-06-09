shader_type spatial;

uniform usampler2D mesh_data;
uniform sampler2D atlas;
uniform float k;
// Mesh data
// Every 10 bytes:
// A --- B
// | uv
// | index
// C
// 3 byte A pos 
// 3 byte B pos 
// 3 byte C pos 
// D pos is calculated as B + C - A
// 1 byte uv index

void vertex() {
	VERTEX.z += max(0.0, 1.0 - abs(float(VERTEX_ID) - k)) * 0.1;
	
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
