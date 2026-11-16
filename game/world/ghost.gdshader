shader_type spatial;
// The ghost rider: see-through and glowing cyan, brightest at the outline.
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.35, 0.9, 1.0);

void fragment() {
    float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float glow = 0.18 + 0.85 * pow(rim, 2.2);
    ALBEDO = tint * glow;
    ALPHA = 1.0;
}
