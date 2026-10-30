shader_type canvas_item;

## Indexed-colour palette swap (v0.2 §5.2). Red channel of the texture is an
## index 0..31; colours come from a 32-wide palette texture (1×32 RGB).

uniform sampler2D palette_tex : filter_nearest, repeat_disable;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float idx = clamp(floor(src.r * 31.0 + 0.5), 0.0, 31.0);
	vec4 pal = texture(palette_tex, vec2((idx + 0.5) / 32.0, 0.5));
	COLOR = vec4(pal.rgb, src.a * pal.a);
}
