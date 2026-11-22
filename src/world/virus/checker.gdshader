shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(1.0, 0.122, 0.706, 1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float cell = 4.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 index = floor(world_position / cell);
	vec4 base = mix(color_a, color_b, mod(index.x + index.y, 2.0));
	COLOR = vec4(base.rgb, base.a * COLOR.a);
}
