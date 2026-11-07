shader_type canvas_item;
render_mode unshaded;

uniform vec4 bounds;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool old_text = false;
uniform vec2 viewport_size;

void fragment() {
	vec2 canvas_position = SCREEN_UV * viewport_size;
	float slant = 0.22;
	float margin = bounds.w * slant * 0.5 + 52.0;
	float center = mix(-margin, bounds.z + margin, progress);
	float projected = canvas_position.x - bounds.x + slant * (canvas_position.y - bounds.y - bounds.w * 0.5);
	// discard 同时适用于普通字体和 MSDF 字体，避免字体管线重新计算透明度。
	if ((old_text && projected < center) || (!old_text && projected >= center)) {
		discard;
	}
}
