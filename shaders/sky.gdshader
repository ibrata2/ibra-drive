shader_type sky;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.4, 0.38, 0.35);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float stars = 0.0;
uniform float clouds = 0.1;
uniform vec2 cloud_offset = vec2(0.0);
uniform float sun_visible = 1.0;
uniform float moon_visible = 0.0;

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(up, 0.55));
	if (d.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-d.y * 5.0, 0.0, 1.0));
	}
	if (AT_CUBEMAP_PASS == false) {
		// الشمس
		if (LIGHT0_ENABLED) {
			float sd = dot(d, LIGHT0_DIRECTION);
			col += sun_color * (smoothstep(0.9993, 0.9997, sd) * 6.0 + pow(max(sd, 0.0), 180.0) * 0.6) * sun_visible;
		}
		if (LIGHT1_ENABLED) {
			float md = dot(d, LIGHT1_DIRECTION);
			col += vec3(0.85, 0.9, 1.0) * smoothstep(0.9995, 0.9998, md) * 2.0 * moon_visible;
		}
		// النجوم
		vec3 sp = floor(d * 260.0);
		float h = fract(sin(dot(sp, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
		col += vec3(step(0.9975, h) * stars * up * (0.6 + 0.4 * sin(TIME * 2.0 + h * 50.0)));
	}
	// الغيوم
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.12) * 0.7 + cloud_offset;
		float c = fbm(uv * 1.3);
		float cov = smoothstep(1.0 - clouds * 0.9 - 0.12, 1.0 - clouds * 0.9 + 0.25, c + clouds * 0.35);
		cov *= smoothstep(0.0, 0.18, d.y);
		col = mix(col, cloud_color * (0.82 + c * 0.25), cov * 0.92);
	}
	COLOR = col;
}
