shader_type canvas_item;

uniform bool invulnerable = false;
uniform float blink_speed = 10.0;
uniform float minimum_opacity : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	if (invulnerable) {
		float pulse = step(0.0, sin(TIME * blink_speed * 6.283185));
		COLOR.a *= mix(minimum_opacity, 1.0, pulse);
	}
}
