shader_type canvas_item;

uniform vec2 resolution = vec2(600.0, 400.0);
uniform vec3 spiral_color: source_color = vec3(0.2, 0.6, 0.3);
uniform float frequency: hint_range(1.0, 10.0, 0.1) = 8.0;
uniform float speed: hint_range(1.0, 20.0, 0.1) = 8.0;
uniform float brightness: hint_range(1.0, 10.0, 0.1) = 5.0;
uniform float balance: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float octaves: hint_range(1.0, 10.0, 1.0) = 4.0;

float draw_spiral(vec2 uv, float rotation) {
	float uv_radius = length(uv);
	float uv_phi = atan(uv.y, uv.x) + rotation;
	float spiral_phi = (log(uv_radius) * frequency - uv_phi) / TAU;
	float spiral_ceil_radius = exp((TAU * ceil(spiral_phi) + uv_phi) / frequency);
	float spiral_floor_radius = exp((TAU * floor(spiral_phi) + uv_phi) / frequency);
	return mix(mix(abs(uv_radius - spiral_ceil_radius), abs(uv_radius - spiral_floor_radius), balance), max(abs(uv_radius - spiral_ceil_radius), abs(uv_radius - spiral_floor_radius)), balance);
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= resolution.x / resolution.y;
	float spiral = 0.0;
	for (float i = 0.0; i < octaves; i += 1.0) {
		spiral += draw_spiral(uv, TIME * speed * (0.5 + sin(i)));
	}
	spiral /= octaves;
	vec3 color = spiral * spiral_color;
	COLOR = vec4(color * brightness, 1.0);
}
