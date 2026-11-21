shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 1.0) = 0.8;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float light = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(light * darken), amount);
	COLOR = color * tint;
}
