// Workshop floor: dark surface with anti-aliased minor/major grid lines that
// fade with distance. Lines are emissive so they stay readable in shadow.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.03, 0.035, 0.045, 1.0);
uniform vec4 line_color : source_color = vec4(0.169, 0.831, 0.91, 1.0);
uniform float cell_size = 1.0;
uniform float major_every = 5.0;
uniform float line_width = 1.1;
uniform float minor_strength = 0.035;
uniform float major_strength = 0.11;
uniform float axis_strength = 0.28;
uniform float fade_start = 12.0;
uniform float fade_end = 40.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float size, float width) {
	vec2 coord = p / size;
	vec2 deriv = fwidth(coord);
	vec2 g = abs(fract(coord - 0.5) - 0.5) / max(deriv, vec2(1e-5));
	return 1.0 - min(min(g.x, g.y) / width, 1.0);
}

float axis_line(float v, float width) {
	float d = fwidth(v);
	return 1.0 - min(abs(v) / max(d, 1e-5) / width, 1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float minor = grid_line(p, cell_size, line_width);
	float major = grid_line(p, cell_size * major_every, line_width * 1.3);
	float axis = max(axis_line(p.x, 1.6), axis_line(p.y, 1.6));
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	float intensity = max(max(minor * minor_strength, major * major_strength), axis * axis_strength) * fade;
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.7;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	EMISSION = line_color.rgb * intensity;
}
