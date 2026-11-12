shader_type spatial;
render_mode cull_disabled;

uniform vec3 car_pos = vec3(0.0, -1000.0, 0.0);
uniform float wind = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float snow = 0.0;
uniform float wet = 0.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float sway = sin(TIME * 1.6 * (0.6 + wind * 0.4) + origin.x * 0.35 + origin.z * 0.27) * 0.1 * wind * h
		+ sin(TIME * 3.1 + origin.x * 1.3) * 0.03 * wind * h;
	vec3 d = origin - car_pos;
	float dist = length(d.xz);
	float push = (1.0 - smoothstep(0.8, 3.2, dist)) * h * 0.9 * step(abs(d.y), 3.0);
	vec2 dir = dist > 0.01 ? d.xz / dist : vec2(0.0);
	vec3 off = vec3(sway + dir.x * push, -push * 0.45, sway * 0.6 + dir.y * push);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * tint;
	c = mix(c, vec3(0.93, 0.95, 1.0), snow * smoothstep(0.0, 1.0, COLOR.g));
	c *= mix(1.0, 0.75, wet);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.35;
}
