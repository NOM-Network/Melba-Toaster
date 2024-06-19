shader_type canvas_item;
render_mode blend_add;

const int VU_COUNT = 120;
const float segment_count = 50.0;

uniform vec4 low_color : source_color = vec4(0.0, 2.0, 1.0, 1.0);
uniform vec4 high_color : source_color = vec4(2.0, 0.0, 0.0, 1.0);
uniform float[VU_COUNT] freq_data;

void fragment() {
	vec2 uv = UV;
	uv.y = 1.0 - uv.y;
	float vu_count = float(VU_COUNT);
	vec2 pos = vec2(floor(uv.x * vu_count) / vu_count, floor(uv.y * segment_count) / segment_count);
	float fft = freq_data[int(uv.x * vu_count)];
	vec4 color = mix(low_color, high_color, sqrt(uv.y));
	float mask = pos.y < fft ? 1.0 : 0.1;
	vec2 dist = fract((uv - pos) * vec2(vu_count, segment_count)) - 0.5;
	COLOR = vec4(color * mask);
}
