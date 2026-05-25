shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 sample = texture(TEXTURE, UV);
	// 黑色描边图标：用 alpha 或亮度作为遮罩，再套用 tint
	float mask = max(sample.a, dot(sample.rgb, vec3(0.299, 0.587, 0.114)));
	COLOR = vec4(tint_color.rgb, mask * tint_color.a);
}
