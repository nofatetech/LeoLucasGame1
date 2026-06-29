// Red/cyan anaglyph (old-school 3D glasses). Reads the rendered frame and splits the
// red channel from the cyan by a small horizontal offset. Our layered flat shapes give
// it real parallax. Wear red-left / cyan-right glasses.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float separation : hint_range(0.0, 0.02) = 0.005;

void fragment() {
	float r = texture(screen_tex, SCREEN_UV - vec2(separation, 0.0)).r;
	vec3 cyan = texture(screen_tex, SCREEN_UV + vec2(separation, 0.0)).rgb;
	COLOR = vec4(r, cyan.g, cyan.b, 1.0);
}
