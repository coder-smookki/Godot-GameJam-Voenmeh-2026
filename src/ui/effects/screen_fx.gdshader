shader_type canvas_item;

uniform float vignette = 0.42;
uniform float grain = 0.03;
uniform vec2 grid = vec2(480.0, 270.0);

void fragment() {
	vec2 offset = UV - 0.5;
	float distance_squared = dot(offset, offset) * 2.0;
	float shade = smoothstep(0.22, 1.0, distance_squared) * vignette;
	vec2 cell = floor(UV * grid);
	float noise = fract(sin(dot(cell + floor(TIME * 12.0), vec2(12.9898, 78.233))) * 43758.5453);
	shade += (noise - 0.5) * grain;
	COLOR = vec4(0.0, 0.0, 0.03, clamp(shade, 0.0, 1.0));
}
