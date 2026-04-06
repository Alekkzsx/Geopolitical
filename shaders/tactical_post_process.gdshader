shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float cold_tint : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	
	// Tactical Cold Blue Tint
	vec3 cold_blue = vec3(0.0, 0.4, 0.7);
	color.rgb = mix(color.rgb, cold_blue * color.rgb, cold_tint);
	
	// Vignette (Darker corners)
	float dist = distance(SCREEN_UV, vec2(0.5));
	// We use a smooth function for the vignette to avoid harsh transitions
	color.rgb *= smoothstep(0.8, 0.5, dist * (vignette_intensity + 0.3));
	
	// Subtle Scanlines
	float scanline = sin(SCREEN_UV.y * 1000.0) * 0.5 + 0.5;
	color.rgb = mix(color.rgb, color.rgb * 0.9, scanline * scanline_opacity);
	
	COLOR = color;
}
