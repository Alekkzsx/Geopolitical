shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float glow_intensity : hint_range(1.0, 50.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	// A simple pulsing glow effect
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	vec4 final_color = border_color * glow_intensity * pulse;
	
	// Ensure the alpha from the original Line2D color is respected
	final_color.a = texture(TEXTURE, UV).a * border_color.a;
	COLOR = final_color;
}
