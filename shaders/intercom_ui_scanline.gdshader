shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_strength : hint_range(0.0, 0.25) = 0.05;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color = texture(screen_tex, uv).rgb;
	float scan = 1.0 - scanline_strength * (0.5 + 0.5 * sin((uv.y * 720.0 + TIME * 8.0) * 3.1415926));
	color *= scan;
	COLOR = vec4(color, overlay_alpha);
}
