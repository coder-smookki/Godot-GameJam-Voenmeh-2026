shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.047, 0.071, 0.125, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float around = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
			around = max(around, texture(TEXTURE, UV + offset).a);
		}
	}
	vec4 outline = vec4(outline_color.rgb, around * outline_color.a);
	COLOR = mix(outline, vec4(base.rgb, 1.0), base.a);
}
