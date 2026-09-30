shader_type canvas_item;

uniform float grain_strength : hint_range(0.0, 0.25) = 0.12;
uniform float grain_flicker_amount : hint_range(0.0, 0.25) = 0.1;

void fragment() {
	vec2 uv = UV;
	vec2 animated_uv = uv + vec2(TIME * 0.07, TIME * 0.11);
	vec3 grain_tex = texture(TEXTURE, animated_uv).rgb;
	float mono_noise = (grain_tex.r + grain_tex.g + grain_tex.b) / 3.0;
	float centered_noise = (mono_noise - 0.5) * 2.0;
	float animated_strength = grain_strength * (1.0 + sin(TIME * 23.0) * grain_flicker_amount);
	float value = centered_noise * animated_strength;
	COLOR = vec4(vec3(0.5 + value), clamp(animated_strength * 1.2, 0.0, 1.0));
}
