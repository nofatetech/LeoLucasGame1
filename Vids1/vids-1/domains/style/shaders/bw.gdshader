// Black & white (silent-film look). Luminance of the rendered frame.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(l), 1.0);
}
