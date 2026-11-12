shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform float night = 0.0;
uniform float wet = 0.0;
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = hash12(origin.xz * 0.37);
	vec3 base = mix(vec3(0.78, 0.72, 0.62), vec3(0.55, 0.58, 0.62), seed);
	base = mix(base, vec3(0.86, 0.82, 0.74), step(0.7, hash12(origin.xz * 1.7)));
	if (wnorm.y > 0.5) {
		ALBEDO = pow(base * 0.55, vec3(2.2));
		ROUGHNESS = 0.9;
	} else {
		float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
		float y = wpos.y - origin.y;
		vec2 cell = vec2(u / 2.6, y / 3.2);
		vec2 f = fract(cell);
		float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.25, f.y) * step(f.y, 0.8) * step(1.0, y);
		float lit = step(0.55, hash12(floor(cell) + origin.xz)) * night;
		vec3 glass = mix(vec3(0.12, 0.16, 0.2), vec3(0.3, 0.38, 0.45), hash12(floor(cell)));
		ALBEDO = pow(mix(base * (0.9 + 0.1 * vnoise(wpos.xz)), glass, win), vec3(2.2));
		ROUGHNESS = mix(0.85, 0.15, win);
		METALLIC = win * 0.4;
		EMISSION = vec3(1.0, 0.78, 0.45) * win * lit * 1.6;
	}
	ALBEDO *= mix(1.0, 0.8, wet);
}
