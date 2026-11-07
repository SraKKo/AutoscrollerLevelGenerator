shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_count : hint_range(120.0, 1200.0) = 480.0;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.05;

uniform float chroma_offset : hint_range(0.0, 5.0) = 1.0;
uniform float curvature : hint_range(0.0, 0.3) = 0.08;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Curvature
	vec2 c = uv * 2.0 - 1.0;
	vec2 cc = c * (1.0 + curvature * (c.yx * c.yx));
	uv = (cc * 0.5 + 0.5);

	vec3 col = vec3(0.0);
	bool inside = (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0);

	if (inside) {
		// Chromatic aberration
		vec2 off = chroma_offset * SCREEN_PIXEL_SIZE;

		float r = texture(SCREEN_TEXTURE, uv + vec2(off.x, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(off.x, 0.0)).b;
		col = vec3(r, g, b);

		// Scanlines
		float scan = sin(uv.y * scanline_count * 3.14159);
		float scan_mask = mix(1.0, 0.5 + 0.5 * scan, scanline_strength);
		col *= scan_mask;

		// Vignette
		vec2 dv = uv - 0.5;
		float vig = 1.0 - vignette_strength * smoothstep(0.2, 0.75, dot(dv, dv) * 1.8);
		col *= vig;

		// Noise
		float n = rand(uv * vec2(1920.0, 1080.0) + TIME);
		col += (n - 0.5) * noise_strength;
	}

	COLOR = vec4(col, 1.0);
}
