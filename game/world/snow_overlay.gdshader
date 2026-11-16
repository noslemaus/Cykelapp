shader_type spatial;
// A layer of snow over a prop (houses, boats, fences) in winter: drawn on top of its own materials,
// only where the surface faces up, nudged out a little so it never flickers against the paint.
render_mode blend_mix, depth_draw_never, cull_back;

global uniform float snow_amount;

varying vec3 wn;

void vertex() {
    wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    VERTEX += NORMAL * 0.02;
}

void fragment() {
    float lie = smoothstep(0.55, 0.85, wn.y);
    ALBEDO = vec3(0.76, 0.79, 0.85);
    ROUGHNESS = 0.8;
    ALPHA = lie * snow_amount;
}
