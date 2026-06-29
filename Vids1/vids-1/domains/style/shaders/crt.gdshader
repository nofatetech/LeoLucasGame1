// CRT / retro: scanlines + soft vignette over the rendered frame.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float scanline_count : hint_range(100.0, 2000.0) = 700.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	c *= 0.9 + 0.1 * sin(uv.y * scanline_count);                 // scanlines
	float vig = smoothstep(0.0, 0.35, uv.x) * smoothstep(1.0, 0.65, uv.x)
		* smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.65, uv.y);
	c *= mix(0.75, 1.0, vig);                                    // vignette
	COLOR = vec4(c, 1.0);
}
