shader_type canvas_item;

/// Globe DECAL wrap for face features (eyes, mouth, blush, …).
///
/// Unlike the landmass shader (equirectangular world map), this treats TEXTURE
/// as a sticker on the sphere. It can slide around with yaw, go behind the
/// globe (hidden), and come back the other side — without the
/// front_world_fraction stretch tradeoff.
///
/// Authoring: paint the feature filling the frame (transparent padding OK).
/// Place it on the globe with decal_center; size it with decal_size.
///
/// wrap_enabled = false → normal sprite (local UV).

uniform bool wrap_enabled = true;
uniform float yaw : hint_range(0.0, 1.0) = 0.0;
uniform float pitch : hint_range(-1.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.15) = 0.03;
uniform float limb_darken : hint_range(0.0, 1.0) = 0.0;
uniform float sphere_warp : hint_range(0.0, 1.0) = 1.0;
/// Extra UV scroll in decal space (e.g. gaze), not world unwrap.
uniform vec2 uv_offset = vec2(0.0, 0.0);
/// Sphere disc radius as a fraction of the sprite half-extent (1 = full square).
uniform float warp_radius : hint_range(0.05, 1.0) = 0.732;
/// Where the sticker sits on the globe (lon, lat) in 0..1. 0.5/0.5 = front center.
uniform vec2 decal_center = vec2(0.5, 0.5);
/// Sticker size in globe turns (1.0 = full 360°). ~0.12–0.25 is typical for an eye.
uniform vec2 decal_size = vec2(0.5, 0.9);
/// Soft fade as the feature center approaches the limb / goes behind.
uniform float backside_softness : hint_range(0.0, 0.2) = 0.06;

void fragment() {
	if (!wrap_enabled) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float radius = clamp(warp_radius, 0.05, 1.0);
		float r = length(p);
		if (r > radius) {
			discard;
		}

		vec2 pg = p / radius;
		float r2 = dot(pg, pg);
		float z_sphere = sqrt(max(0.0, 1.0 - r2));
		float warp = clamp(sphere_warp, 0.0, 1.0);
		float z = max(mix(1.0, z_sphere, warp), 0.001);

		// Fragment longitude / latitude in 0..1 turns (full 360° / 180° span).
		float lon_unit = mix(pg.x, atan(pg.x, z) / (PI * 0.5), warp);
		float lat_unit = mix(pg.y, asin(clamp(pg.y, -1.0, 1.0)) / (PI * 0.5), warp);
		// World longitude painted at this screen point (front = 180° / half the turns).
		// Yaw scrolls which world longitude faces the camera — same as landmass.
		float frag_lon = fract(lon_unit * 0.25 + 0.5 + yaw);
		float frag_lat = clamp(lat_unit * 0.5 + 0.5 + pitch, 0.0, 1.0);

		// Sticker's fixed place on the globe (does NOT include yaw).
		float center_lon = decal_center.x;
		float center_lat = decal_center.y;

		// Hide / fade when the sticker is on the back hemisphere.
		// Camera faces world lon = fract(0.5 + yaw); back is > 90° away.
		float cam_lon = fract(0.5 + yaw);
		float dlon_cam = center_lon - cam_lon;
		dlon_cam = dlon_cam - floor(dlon_cam + 0.5);
		float back_fade = 1.0 - smoothstep(
			0.25 - backside_softness,
			0.25 + backside_softness,
			abs(dlon_cam)
		);
		if (back_fade <= 0.001) {
			discard;
		}

		// Offset from sticker center → local decal UV (yaw moves this on screen).
		float dlon = frag_lon - center_lon;
		dlon = dlon - floor(dlon + 0.5);
		float dlat = frag_lat - center_lat;

		vec2 size = max(decal_size, vec2(0.001));
		vec2 decal_uv = vec2(dlon / size.x, dlat / size.y) + vec2(0.5) + uv_offset;
		if (decal_uv.x < 0.0 || decal_uv.x > 1.0 || decal_uv.y < 0.0 || decal_uv.y > 1.0) {
			discard;
		}

		vec4 tex = texture(TEXTURE, decal_uv);
		float rg = sqrt(r2);
		float edge_alpha = 1.0 - smoothstep(1.0 - edge_softness, 1.0, rg);
		float shade = mix(1.0 - limb_darken * warp, 1.0, z_sphere);
		COLOR = vec4(tex.rgb * shade, tex.a * edge_alpha * back_fade);
	}
}
