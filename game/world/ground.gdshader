shader_type spatial;
// Surface detail for the low-poly ground and rocks, all procedural (no image textures):
//   granite  fine grains, broad tone changes, and lichen rosettes (pale grey-green, some orange)
//   grass    patches of fresh green and dry yellow
// The colour comes from the vertex colours (terrain) or `base_color` (rock models).
// Pink-ish colours are treated as granite, green-ish as grass, anything else is left alone.

// Weather and season (world/atmosphere.gd): snow on what faces up, autumn grass, rain-dark ground.
global uniform float snow_amount;
global uniform float autumn_amount;
global uniform float wet_amount;

uniform vec3 base_color : source_color = vec3(1.0);
uniform bool use_vertex_color = true;
uniform float lichen_amount = 0.35;

varying vec3 wpos;
varying vec3 wnormal;

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

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int k = 0; k < 4; k++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

vec3 to_linear(vec3 c) {
    return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 srgb = use_vertex_color ? COLOR.rgb : pow(base_color, vec3(1.0 / 2.2));
    vec3 col = use_vertex_color ? to_linear(COLOR.rgb) : base_color;
    float rock = smoothstep(0.02, 0.09, srgb.r - srgb.g) * step(srgb.b, srgb.r);
    float grass = smoothstep(0.0, 0.07, srgb.g - srgb.r);

    float dist = length(VERTEX);
    vec3 result = col;
    // Only the parts that show are worked out: granite on rock, meadow on grass, cracks close by,
    // the waterline near the sea. Rock and grass come per triangle, so the branches stay coherent.
    if (rock > 0.001) {
        // Granite: broad tone, grains, and lichen on surfaces facing up and out.
        float tone = fbm(wpos * 0.3);
        vec3 granite = col * (0.86 + 0.26 * tone);
        granite *= 0.93 + 0.12 * step(0.72, noise(wpos * 4.0));
        granite = mix(granite, granite * 0.78, step(0.84, noise(wpos * 8.0 + 31.0)));
        float spots = fbm(wpos * 1.6 + 17.0);
        float lichen = smoothstep(0.63, 0.67, spots) * lichen_amount * smoothstep(0.2, 0.6, wnormal.y);
        vec3 lichen_col = mix(to_linear(vec3(0.70, 0.72, 0.58)), to_linear(vec3(0.86, 0.56, 0.24)),
            step(0.82, noise(wpos * 0.35 + 5.0)));
        granite = mix(granite, lichen_col, lichen);
        if (dist < 140.0 && wnormal.y > 0.2) {
            // Cracks and clefts: the edges of a jittered cell pattern (granite splits into
            // angular blocks), only some of them showing, on the flatter tops of the slabs.
            vec2 cp = wpos.xz * 0.32 + (vec2(noise(wpos * 0.9), noise(wpos * 0.9 + 19.0)) - 0.5) * 0.35;
            vec2 cell = floor(cp);
            float d1 = 9.0;
            float d2 = 9.0;
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) {
                    vec2 c = cell + vec2(float(i), float(j));
                    vec2 o = c + vec2(hash(vec3(c, 1.0)), hash(vec3(c, 7.0)));
                    float d = length(cp - o);
                    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
                }
            }
            float edge = 1.0 - smoothstep(0.015, 0.05, d2 - d1);
            float cracks = edge * step(0.42, noise(wpos * 0.4 + 23.0)) * (1.0 - smoothstep(100.0, 140.0, dist));
            granite = mix(granite, granite * 0.45, cracks * smoothstep(0.2, 0.6, wnormal.y));
        }
        result = mix(col, granite, rock);
    }
    if (grass > 0.001 && rock < 0.999) {
        // Grass: big soft patches plus dry yellow tufts, and darker patches of heath (berry sprigs).
        float patchy = fbm(wpos * 0.08 + 40.0);
        vec3 meadow = col * (0.82 + 0.36 * patchy);
        meadow = mix(meadow, meadow * vec3(1.15, 1.08, 0.62), step(0.62, noise(wpos * 1.6)) * 0.45);
        float heath = smoothstep(0.56, 0.64, fbm(wpos * 0.21 + 70.0));
        meadow = mix(meadow, to_linear(vec3(0.33, 0.41, 0.22)), heath * 0.65);
        // Autumn: the grass goes straw-yellow, with rust-brown patches.
        vec3 straw = mix(vec3(0.42, 0.30, 0.10), vec3(0.30, 0.13, 0.05), step(0.6, noise(wpos * 0.25)));
        meadow = mix(meadow, straw * (0.8 + 0.4 * patchy), autumn_amount * 0.85);
        result = mix(result, meadow, grass * (1.0 - rock));
    }
    if (wpos.y < 1.3) {
        // The waterline: a band of black lichen just above the sea, brown bladder wrack (tång)
        // just below it, both with ragged edges.
        float ragged = (fbm(wpos * 0.9 + 3.0) - 0.5) * 0.5;
        float wl = wpos.y + ragged;
        float black_band = (1.0 - smoothstep(0.35, 0.95, wl)) * smoothstep(-0.15, 0.1, wl);
        result = mix(result, result * vec3(0.36, 0.34, 0.32), black_band * 0.85);
        float wrack = (1.0 - smoothstep(-0.25, -0.05, wl)) * smoothstep(-1.6, -1.0, wl);
        result = mix(result, to_linear(vec3(0.36, 0.31, 0.14)) * (0.8 + 0.4 * noise(wpos * 3.0)), wrack);
    }
    float rough = 0.92;
    // Rain: darker and glossier, the rock most.
    result *= 1.0 - 0.38 * wet_amount;
    rough = mix(rough, mix(0.55, 0.3, rock), wet_amount);
    // Snow settles where the ground faces up; steep rock and the cracks stay dark.
    if (snow_amount > 0.0) {
        float lie = smoothstep(0.5, 0.85, wnormal.y + (fbm(wpos * 0.45 + 9.0) - 0.5) * 0.55);
        vec3 snow = mix(vec3(0.66, 0.71, 0.80), vec3(0.80, 0.82, 0.87), noise(wpos * 1.3));
        result = mix(result, snow, snow_amount * lie);
        rough = mix(rough, 0.75, snow_amount * lie);
    }
    ALBEDO = result;
    ROUGHNESS = rough;
}
