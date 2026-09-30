shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float chromatic_aberration_strength : hint_range(0.0, 0.01) = 0.0012;
uniform float blur_strength : hint_range(0.0, 2.0) = 0.65;
uniform float fisheye_strength : hint_range(0.0, 0.25) = 0.06;
uniform float fisheye_zoom : hint_range(0.5, 1.5) = 1.0;
uniform vec2 fisheye_center = vec2(0.5, 0.5);
uniform float scanline_strength : hint_range(0.0, 0.25) = 0.05;
uniform float scanline_density : hint_range(64.0, 2048.0) = 720.0;
uniform float scanline_speed : hint_range(0.0, 40.0) = 8.0;
uniform float long_scanline_strength : hint_range(0.0, 0.35) = 0.08;
uniform float long_scanline_thickness : hint_range(0.001, 0.2) = 0.03;
uniform float long_scanline_speed : hint_range(0.0, 2.0) = 0.18;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = (uv - fisheye_center) * 2.0;
	float radius2 = dot(centered, centered);
	vec2 warped = centered * (1.0 + fisheye_strength * radius2);
	vec2 uv_warped = (warped * 0.5) + fisheye_center;
	uv_warped = (uv_warped - fisheye_center) / fisheye_zoom + fisheye_center;
	vec2 uv_sample = clamp(uv_warped, vec2(0.0), vec2(1.0));
	vec2 texel = SCREEN_PIXEL_SIZE * blur_strength;
	vec2 ca = vec2(chromatic_aberration_strength, 0.0);

	// Subtle chromatic aberration.
	float r = texture(screen_tex, uv_sample + ca).r;
	float g = texture(screen_tex, uv_sample).g;
	float b = texture(screen_tex, uv_sample - ca).b;
	vec3 aberrated = vec3(r, g, b);

	// Subtle 5-tap blur.
	vec3 blurred =
		texture(screen_tex, uv_sample).rgb * 0.4 +
		texture(screen_tex, uv_sample + vec2(texel.x, 0.0)).rgb * 0.15 +
		texture(screen_tex, uv_sample - vec2(texel.x, 0.0)).rgb * 0.15 +
		texture(screen_tex, uv_sample + vec2(0.0, texel.y)).rgb * 0.15 +
		texture(screen_tex, uv_sample - vec2(0.0, texel.y)).rgb * 0.15;

	vec3 color = mix(aberrated, blurred, 0.7);

	// Subtle animated scanlines.
	float scan = 1.0 - scanline_strength * (0.5 + 0.5 * sin((uv.y * scanline_density + TIME * scanline_speed) * 3.1415926));
	color *= scan;

	// Optional slow moving long-period scanline band.
	float long_center = fract(TIME * long_scanline_speed);
	float long_dist = abs(uv.y - long_center);
	float long_band = smoothstep(long_scanline_thickness, 0.0, long_dist);
	color *= 1.0 - (long_band * long_scanline_strength);

	vec3 base = texture(screen_tex, uv_sample).rgb;
	vec3 final_rgb = mix(base, clamp(color, 0.0, 1.0), overlay_alpha);
	COLOR = vec4(final_rgb, 1.0);
}
