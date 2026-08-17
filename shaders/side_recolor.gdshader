shader_type canvas_item;

// The black side is a recolour of the white side, applied once to the whole
// character (art contract rule 2 / duel-panel-and-rig task 8), never per part.

uniform bool is_black = false;
uniform vec3 black_tint : source_color = vec3(0.06, 0.06, 0.09);
uniform float black_mix = 0.6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (is_black) {
		vec3 darkened = mix(c.rgb * 0.4, black_tint, 0.35);
		c.rgb = mix(c.rgb, darkened, black_mix);
	}
	COLOR = c;
}
