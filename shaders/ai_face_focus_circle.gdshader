shader_type canvas_item;
render_mode unshaded;

/// Circular focus mask for a CanvasGroup that composites AIFace.
/// Samples CanvasGroup backbuffer; mask is in stable screen-pixel space
/// (UV space bobs when child bounds change).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

/// Face center in SCREEN_UV (updated by AIFaceFocusMask).
uniform vec2 focus_center_screen_uv = vec2(0.5, 0.5);
/// Circle radius in screen pixels.
uniform float focus_radius_px : hint_range(1.0, 512.0, 0.5) = 72.0;
/// Soft edge width in screen pixels.
uniform float focus_feather_px : hint_range(0.0, 128.0, 0.5) = 10.0;
uniform float opacity : hint_range(0.0, 1.0, 0.001) = 1.0;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}

	vec2 frag_px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 center_px = focus_center_screen_uv / SCREEN_PIXEL_SIZE;
	float dist = distance(frag_px, center_px);

	float edge_end = focus_radius_px + max(focus_feather_px, 0.001);
	float mask = 1.0 - smoothstep(focus_radius_px, edge_end, dist);

	c *= mask * opacity;
	COLOR *= c;
}
