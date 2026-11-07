shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = UV;
	vec3 base = mix(vec3(0.027, 0.041, 0.105), vec3(0.065, 0.044, 0.16), p.x);
	float violet = exp(-dot((p - vec2(0.63, 0.12)) * vec2(1.65, 2.1), (p - vec2(0.63, 0.12)) * vec2(1.65, 2.1)) * 4.0);
	float pink = exp(-dot((p - vec2(0.94, 0.54)) * vec2(2.1, 1.7), (p - vec2(0.94, 0.54)) * vec2(2.1, 1.7)) * 4.0);
	float cyan = exp(-dot((p - vec2(0.39, 0.95)) * vec2(1.6, 2.4), (p - vec2(0.39, 0.95)) * vec2(1.6, 2.4)) * 4.0);
	base += violet * vec3(0.16, 0.075, 0.31) + pink * vec3(0.21, 0.045, 0.17) + cyan * vec3(0.015, 0.17, 0.20);
	COLOR = vec4(base, 1.0);
}
