shader_type canvas_item;

// Deprecated placeholder kept only to satisfy stale editor references.
// Real effect stack now uses separate shaders:
// - intercom_ui_chromatic.gdshader
// - intercom_ui_blur.gdshader
// - intercom_ui_scanline.gdshader

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	COLOR = texture(screen_tex, SCREEN_UV);
}
