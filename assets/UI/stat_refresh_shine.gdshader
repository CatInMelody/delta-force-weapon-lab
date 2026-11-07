shader_type canvas_item;
render_mode unshaded;

uniform vec4 bounds;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
varying vec2 canvas_position;

void vertex() {
	canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float margin = bounds.w * 0.22 * 0.5 + 52.0;
	float center = mix(-margin, bounds.z + margin, progress);
	float projected = canvas_position.x - bounds.x + 0.22 * (canvas_position.y - bounds.y - bounds.w * 0.5);
	float distance_to_light = projected - center;
	float glow = exp(-pow(distance_to_light / 32.0, 2.0)) * 0.24;
	float core = exp(-pow(distance_to_light / 8.0, 2.0)) * 0.64;
	COLOR = vec4(1.0, 1.0, 1.0, glow + core);
}
