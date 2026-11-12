shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.32, 0.86, 0.76);
uniform vec3 deep_color : source_color = vec3(0.04, 0.28, 0.42);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float depth_scale = 0.18;
uniform float foam_width = 1.4;
uniform float wave_amp = 0.12;
uniform float wave_speed = 1.0;
uniform float lava = 0.0;
uniform float murky = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wpos.x * 0.13 + TIME * 1.1 * wave_speed) * 0.5 + sin(wpos.z * 0.19 + TIME * 0.8 * wave_speed) * 0.5;
	VERTEX.y += w * wave_amp;
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float scene_depth = -v.z;
	float water_depth = max(scene_depth - (-VERTEX.z), 0.0);
	float t = clamp(water_depth * depth_scale, 0.0, 1.0);
	vec2 flow = wpos.xz * 0.08 + vec2(TIME * 0.03, TIME * 0.02) * wave_speed;
	float n1 = fbm(flow * 3.0);
	float n2 = fbm(flow * 3.0 + vec2(5.2, 1.3) + TIME * 0.02);
	vec3 col = mix(shallow_color, deep_color, t);
	col = mix(col, vec3(0.32, 0.3, 0.2), murky * 0.6);
	float edge = 1.0 - smoothstep(0.0, foam_width, water_depth);
	float foam_n = vnoise(wpos.xz * 1.6 + TIME * 0.6 * wave_speed);
	float foam = smoothstep(0.35, 0.75, edge * (0.6 + foam_n * 0.8));
	foam += smoothstep(0.78, 0.95, n1 * n2 * 2.2) * 0.35 * (1.0 - t * 0.5);
	foam = clamp(foam, 0.0, 1.0);
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.6, 1.0, (n2 - 0.5) * 0.6));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nrm, 0.0)).xyz, 0.5));
	if (lava > 0.5) {
		float l = fbm(wpos.xz * 0.12 + TIME * 0.04);
		float cracks = smoothstep(0.45, 0.6, l);
		ALBEDO = mix(vec3(0.9, 0.25, 0.02), vec3(0.08, 0.04, 0.03), cracks);
		EMISSION = mix(vec3(4.0, 1.1, 0.1), vec3(0.2, 0.03, 0.0), cracks) * (0.8 + n1 * 0.6);
		ROUGHNESS = 0.8;
		ALPHA = 1.0;
	} else {
		ALBEDO = mix(col, foam_color, foam);
		ROUGHNESS = mix(0.05, 0.6, foam);
		SPECULAR = 0.6;
		ALPHA = clamp(mix(0.55, 0.96, t) + foam * 0.5, 0.0, 1.0);
	}
}
