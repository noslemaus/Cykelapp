shader_type spatial;
// The light pillar over a teleport gate: a cyan beam that rises into the sky and fades upwards, with a
// slow pulse running up it and a white-hot core, so every portal can be seen from the lap and from far
// away (also over trees and buildings, against a bright sky and through fog).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.25, 0.85, 1.0);
uniform float beam_height = 160.0;

varying float h;

void vertex() {
    h = VERTEX.y + beam_height * 0.5;
}

void fragment() {
    float t = clamp(h / beam_height, 0.0, 1.0);
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float fade = (1.0 - t) * smoothstep(0.0, 0.015, t);
    float pulse = 0.85 + 0.15 * sin(TIME * 2.0 - t * 14.0);
    vec3 col = mix(tint, vec3(0.92, 1.0, 1.0), pow(facing, 6.0));
    ALBEDO = col * 1.6 * pulse;
    ALPHA = clamp(pow(facing, 1.5) * fade * 0.9, 0.0, 1.0);
}
