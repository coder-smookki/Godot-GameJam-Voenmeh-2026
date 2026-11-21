shader_type canvas_item;

uniform float strength = 0.1;

void fragment() {
	float line = mod(floor(FRAGCOORD.y), 2.0);
	COLOR = vec4(0.0, 0.0, 0.0, line * strength);
}
