shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/noise.gdshaderinc"

uniform float wetness = 0.0;
uniform float snow_cover = 0.0;
uniform float ripples = 0.0;
uniform vec3 snow_color : source_color = vec3(0.94, 0.96, 1.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float n = vnoise(wpos.xz * 0.35) * 0.45 + vnoise(wpos.xz * 2.2) * 0.35 + vnoise(wpos.xz * 9.0) * 0.2;
	c *= 0.86 + n * 0.28;
	// تموجات الرمل
	float rip = sin(wpos.x * 1.7 + wpos.z * 0.6 + vnoise(wpos.xz * 0.15) * 9.0);
	c *= 1.0 + rip * 0.035 * ripples;
	// ثلج يتراكم على الأسطح المستوية
	float flatness = smoothstep(0.55, 0.9, wnorm.y);
	float s = clamp(flatness * snow_cover * 1.4 - (1.0 - n) * 0.35, 0.0, 1.0);
	c = mix(c, snow_color * (0.92 + n * 0.1), s);
	float wet = wetness * (1.0 - s);
	c *= mix(1.0, 0.62, wet);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.32, wet);
	SPECULAR = mix(0.25, 0.6, wet);
}
