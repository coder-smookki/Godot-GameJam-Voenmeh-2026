shader_type canvas_item;

uniform float cell = 10.0;
uniform float rate = 5.0;
uniform float amount = 0.07;
uniform float tear = 0.0;

varying vec4 tint;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float tick = floor(TIME * rate);
	vec2 uv = UV;
	float row = floor(pixel.y / 6.0);
	if (hash(vec2(row, tick)) < tear) {
		uv.x += (hash(vec2(tick, row)) - 0.5) * 8.0 * TEXTURE_PIXEL_SIZE.x;
	}
	vec4 color = texture(TEXTURE, uv);
	bool pink = color.r > 0.7 && color.g < 0.35 && color.b > 0.7;
	bool dark = color.r < 0.12 && color.b < 0.06 && color.g > color.r + 0.03 && color.g < 0.2;
	float roll = hash(floor(pixel / cell) + vec2(tick * 0.37, tick * 0.11));
	if (roll < amount && (pink || dark)) {
		color.rgb = pink ? vec3(0.0, 0.07, 0.0) : vec3(1.0, 0.0, 1.0);
	}
	COLOR = color * tint;
}
