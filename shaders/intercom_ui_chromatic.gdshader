shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float chromatic_aberration_strength : hint_range(0.0, 0.01) = 0.0012;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ca = vec2(chromatic_aberration_strength, 0.0);
	float r = texture(screen_tex, uv + ca).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - ca).b;
	COLOR = vec4(vec3(r, g, b), overlay_alpha);
}
