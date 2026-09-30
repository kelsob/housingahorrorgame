shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float blur_strength : hint_range(0.0, 2.0) = 0.65;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = SCREEN_PIXEL_SIZE * blur_strength;
	vec3 color =
		texture(screen_tex, uv).rgb * 0.4 +
		texture(screen_tex, uv + vec2(texel.x, 0.0)).rgb * 0.15 +
		texture(screen_tex, uv - vec2(texel.x, 0.0)).rgb * 0.15 +
		texture(screen_tex, uv + vec2(0.0, texel.y)).rgb * 0.15 +
		texture(screen_tex, uv - vec2(0.0, texel.y)).rgb * 0.15;
	COLOR = vec4(color, overlay_alpha);
}
