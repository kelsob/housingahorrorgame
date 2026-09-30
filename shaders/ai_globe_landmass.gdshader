shader_type canvas_item;

/// Circular globe fill. The Sprite2D itself should be a SQUARE on screen
/// (that's just the round window). The wide land map is a separate texture
/// assigned on the material as `land_tex` — it is NOT the sprite's Texture.
///
/// land_tex expectations:
/// - Full 360° world strip (equirectangular), typically ~2x wider than tall.
/// - Seamless left↔right if you want clean loops.
/// - Transparent ocean → filled with ocean_color when use_ocean_fill is on.
///
/// Wrap model:
/// - Texture width = 360° around the globe.
/// - The front face shows ~180° (half the texture). The other half is on the back
///   and appears when yaw spins.

uniform sampler2D land_tex : source_color, filter_nearest, repeat_enable;
uniform float yaw : hint_range(0.0, 1.0) = 0.0;
/// Shifts latitude a little (look "up" / "down" the globe).
uniform float pitch : hint_range(-1.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.15) = 0.03;
uniform bool use_ocean_fill = true;
uniform vec4 ocean_color : source_color = vec4(0.18, 0.42, 0.62, 1.0);
/// Darken toward the limb so the disc reads as a ball.
uniform float limb_darken : hint_range(0.0, 1.0) = 0.35;
/// 0 = flatter/cartoony foreshortening. 1 = full hemisphere squeeze at the edges.
/// Does NOT change how much of the map is on the front (always ~180°).
uniform float sphere_warp : hint_range(0.0, 1.0) = 0.45;
/// Fraction of the texture width visible on the front face.
/// 0.5 = correct globe (180° / half the world). 1.0 = plaster whole map on the front.
uniform float front_world_fraction : hint_range(0.25, 1.0) = 0.5;
uniform vec4 outline_color : source_color = vec4(0.08, 0.1, 0.14, 1.0);
/// Ring width in UV radius (0 = off). Insets the globe so the stroke fits in-quad.
uniform float outline_thickness : hint_range(0.0, 0.25) = 0.04;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float thickness = max(outline_thickness, 0.0);
	float globe_r = max(1.0 - thickness, 0.001);
	vec4 col = vec4(0.0);

	if (r <= globe_r) {
		vec2 pg = p / globe_r;
		float r2 = dot(pg, pg);
		float z_sphere = sqrt(max(0.0, 1.0 - r2));
		float warp = clamp(sphere_warp, 0.0, 1.0);

		// Soften depth for cartoon look WITHOUT widening map coverage.
		// warp=0 → z stays high → less edge squeeze; coverage stays ~180°.
		float z = mix(1.0, z_sphere, warp);
		z = max(z, 0.001);

		// Longitude in -1..1 across the front face, then scale by front_world_fraction.
		// Sphere path: atan / (PI/2) maps the true hemisphere to -1..1.
		// Flat path: raw x. Coverage is applied once after the mix.
		float lon_unit = mix(pg.x, atan(pg.x, z) / (PI * 0.5), warp);
		float coverage = clamp(front_world_fraction, 0.25, 1.0);
		float u = fract(lon_unit * coverage * 0.5 + 0.5 + yaw);

		float lat_unit = mix(pg.y, asin(clamp(pg.y, -1.0, 1.0)) / (PI * 0.5), warp);
		float v = clamp(lat_unit * 0.5 + 0.5 + pitch, 0.0, 1.0);

		vec4 land = texture(land_tex, vec2(u, v));
		vec4 base = use_ocean_fill ? mix(ocean_color, land, land.a) : land;

		float rg = sqrt(r2);
		float edge_alpha = 1.0 - smoothstep(1.0 - edge_softness, 1.0, rg);
		float shade = mix(1.0 - limb_darken * warp, 1.0, z_sphere);
		col = vec4(base.rgb * shade, base.a * edge_alpha);
	}

	if (thickness > 0.0) {
		float inner = smoothstep(globe_r - edge_softness, globe_r, r);
		float outer = 1.0 - smoothstep(1.0 - edge_softness, 1.0, r);
		float outline_mask = inner * outer;
		col = mix(col, vec4(outline_color.rgb, 1.0), outline_mask * outline_color.a);
	}

	COLOR = col;
}
