// Color grade - a fullscreen post pass that gives every frame a "look" (tint, contrast,
// saturation, temperature, vignette, film grain). Reads the rendered frame; sits below the
// style shaders so anaglyph/bw/crt compose on top. Neutral defaults = identity (no change).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform float temperature = 0.0;   // -1 cool .. +1 warm
uniform float vignette = 0.0;      // 0..1 corner darkening
uniform float grain = 0.0;         // 0..1 film grain

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// temperature: warm pushes red up / blue down
	col.r += temperature * 0.08;
	col.b -= temperature * 0.08;

	// tint multiply
	col *= tint.rgb;

	// contrast around mid-grey
	col = (col - 0.5) * contrast + 0.5;

	// saturation (luma-preserving)
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);

	// vignette toward the corners
	vec2 d = SCREEN_UV - 0.5;
	col *= clamp(1.0 - vignette * dot(d, d) * 2.2, 0.0, 1.0);

	// film grain - TIME is fixed per recorded frame under Movie Maker, so this is deterministic
	float g = (hash(SCREEN_UV * vec2(1920.0, 1080.0) + vec2(TIME)) - 0.5) * grain * 0.15;
	col += g;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
