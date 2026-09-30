shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 0.25) = 0.06;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float r2 = dot(centered, centered);
	vec2 warped = centered * (1.0 + strength * r2);
	vec2 sample_uv = warped * 0.5 + 0.5;
	bool oob = sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0;
	COLOR = oob ? vec4(0.0) : textureLod(screen_tex, sample_uv, 0.0);
}
