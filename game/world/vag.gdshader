shader_type spatial;
render_mode cull_disabled;
// The road and the bridge decks. Colours come from the vertices (sRGB); UV is (metres across the
// road from the centre line, metres along the lap).
//   asphalt   fine aggregate speckle close by, large faint repair patches, two polished wheel
//             tracks per lane
//   planks    (bridge decks) boards across the deck with dark gaps, each board its own tone
//             and a faint grain

global uniform float wet_amount;
global uniform float snow_amount;

uniform bool planks = false;
varying vec3 wpos;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec3 to_linear(vec3 c) {
    return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 srgb = COLOR.rgb;
    vec3 col = to_linear(srgb);
    float dist = length(VERTEX);
    float rough = 0.9;
    if (planks) {
        float v = UV.y / 0.24;
        float id = floor(v);
        float f = fract(v);
        float gap = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
        float tone = 0.86 + 0.26 * hash(vec3(id, 3.0, 7.0));
        float grain = 0.93 + 0.1 * noise(vec3(UV.x * 2.5, id * 5.3, 1.0));
        col *= tone * grain;
        col = mix(col * 0.3, col, mix(gap, 1.0, smoothstep(40.0, 90.0, dist)));
        rough = 0.82;
    } else {
        float sat = max(srgb.r, max(srgb.g, srgb.b)) - min(srgb.r, min(srgb.g, srgb.b));
        float asphalt = (1.0 - smoothstep(0.05, 0.1, sat)) * (1.0 - smoothstep(0.45, 0.6, srgb.r));
        float close = 1.0 - smoothstep(12.0, 50.0, dist);
        float speck = 1.0 + (noise(wpos * 9.0) - 0.5) * 0.2 * close + (step(0.95, hash(floor(wpos * 18.0))) - 0.05) * 0.1 * close;
        float patches = 0.92 + 0.16 * noise(vec3(wpos.x * 0.11, 0.0, wpos.z * 0.11));
        float u = abs(UV.x);
        float wheel = exp(-pow((u - 0.4) / 0.28, 2.0)) + exp(-pow((u - 1.7) / 0.28, 2.0));
        col *= mix(1.0, speck * patches * (1.0 - 0.06 * wheel), asphalt);
        rough = mix(0.9, 0.72, asphalt * wheel);
    }
    // Rain: dark, glossy asphalt. Winter: a packed, swept road with snow at the edges.
    col *= 1.0 - 0.45 * wet_amount;
    rough = mix(rough, 0.18, wet_amount * (planks ? 0.6 : 1.0));
    float edge = smoothstep(1.55, 2.35, abs(UV.x) + (noise(wpos * 1.7) - 0.5) * 0.6);
    vec3 packed = mix(vec3(0.16, 0.17, 0.19), vec3(0.74, 0.77, 0.83), edge);
    col = mix(col, packed, snow_amount * (planks ? 0.75 : 0.35 + 0.65 * edge));
    ALBEDO = col;
    ROUGHNESS = mix(rough, 0.7, snow_amount);
}
