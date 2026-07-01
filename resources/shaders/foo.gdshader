shader_type canvas_item;

uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;

uniform int wave_count = 3;

uniform float travel_time = 0.6;
uniform float gap_time = 0.0;
uniform float width = 0.3;
uniform vec3 glow_color = vec3(1.0, 0.9, 0.35);
uniform float pause_time = 1.5;
uniform float fade_time = 0.5;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Bottom = 0, Top = 1
	float y = 1.0 - UV.y;

	float ripple = 0.0;

	float wave_period = travel_time + gap_time;
	float burst_duration =
		travel_time +
		float(wave_count - 1) * wave_period;

	float total_cycle = burst_duration + pause_time;

	float t = mod(TIME, total_cycle);

	// Draw every active wave in the burst.
	for (int i = 0; i < wave_count; i++) {

		float wave_start = float(i) * wave_period;
		float local_time = t - wave_start;

		float life_start = -fade_time;
		float life_end = travel_time + fade_time;

		if (local_time >= life_start && local_time <= life_end) {

			//float wave = mix(0, width + (1.5 * width), local_time / travel_time);
			//float wave = local_time / travel_time;
			float progress = clamp(local_time / travel_time, 0.0, 1.0);
			float wave = progress;

			float dist = abs(y - wave);

			float band = 1.0 - smoothstep(0.0, width, dist);

			// Sharpen the center slightly
			band = sqrt(band);

			float fade_in = smoothstep(life_start, 0.0, local_time);
			float fade_out = 1.0 - smoothstep(travel_time, life_end, local_time);
			ripple += (band * fade_in * fade_out);
		}
	}

	ripple = clamp(ripple, 0.0, 1.0);

	color.rgb += glow_color * ripple * effect_strength;

	COLOR = color;
}
