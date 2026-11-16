shader_type spatial;
// The ground of Egypten. Colours come per triangle from the vertices (sRGB): sand, limestone on
// the plateau, green jungle and fields by the Nile, packed earth in the city. This adds what
// shows close by:
//   sand       wind ripples across the dunes, fine grains, and darker patches
//   limestone  broad tone and blocky joints on the plateau
//   chalk      the White Desert: smooth white with wind-scoured streaks
//   green      soft patches and darker tufts
//   waterline  dark wet mud along the Nile and the oasis, then silty green underwater

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
    for (int i = 0; i < 3; i++) {
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
    vec3 srgb = COLOR.rgb;
    vec3 col = to_linear(srgb);
    float dist = length(VERTEX);
    float green = smoothstep(0.0, 0.06, srgb.g - srgb.r);
    float sat = max(srgb.r, max(srgb.g, srgb.b)) - min(srgb.r, min(srgb.g, srgb.b));
    float pale = smoothstep(0.30, 0.20, sat) * step(0.6, srgb.r);
    vec3 result = col;
    if (green < 0.999) {
        // Sand: big soft tone, ripples running across the wind close by, a sparkle of grains.
        float tone = fbm(wpos * 0.04);
        vec3 sand = col * (0.88 + 0.22 * tone);
        float close = 1.0 - smoothstep(25.0, 90.0, dist);
        float warp = noise(wpos * 0.15) * 6.0;
        float ripple = sin(wpos.x * 2.3 + wpos.z * 0.9 + warp);
        sand *= 1.0 + ripple * 0.05 * close * smoothstep(0.6, 0.9, wnormal.y) * (1.0 - pale);
        sand *= 0.96 + 0.08 * step(0.8, noise(wpos * 6.0)) * close;
        if (pale > 0.01) {
            // Limestone: blocky joints and a weathered tone.
            vec2 b = wpos.xz * vec2(0.45, 0.8) + vec2(floor(wpos.z * 0.8) * 0.5, 0.0);
            vec2 f = abs(fract(b) - 0.5);
            float joint = 1.0 - smoothstep(0.44, 0.49, max(f.x, f.y));
            vec3 stone = col * (0.9 + 0.18 * fbm(wpos * 0.3));
            stone = mix(stone * 0.8, stone, mix(joint, 1.0, smoothstep(40.0, 110.0, dist)));
            sand = mix(sand, stone, pale);
        }
        float chalk = smoothstep(0.68, 0.74, min(srgb.r, min(srgb.g, srgb.b)));
        if (chalk > 0.01) {
            // Chalk of the White Desert: smooth and bright, wind-scoured streaks, a soft tone.
            float streak = sin(wpos.x * 0.35 + wpos.z * 0.12 + noise(wpos * 0.05) * 5.0);
            vec3 white = col * (0.93 + 0.08 * fbm(wpos * 0.06)) * (1.0 + streak * 0.025);
            white *= 0.97 + 0.05 * step(0.75, noise(wpos * 4.0)) * close;
            sand = mix(sand, white, chalk);
        }
        result = sand;
    }
    if (green > 0.001) {
        float patchy = fbm(wpos * 0.07 + 40.0);
        vec3 leaf = col * (0.8 + 0.4 * patchy);
        leaf = mix(leaf, leaf * vec3(0.7, 0.85, 0.6), step(0.68, noise(wpos * 1.3)) * 0.5);
        result = mix(result, leaf, green);
    }
    if (wpos.y < 1.0) {
        float ragged = (fbm(wpos * 0.8 + 3.0) - 0.5) * 0.4;
        float wl = wpos.y + ragged;
        float wet = 1.0 - smoothstep(0.1, 0.8, wl);
        result = mix(result, result * vec3(0.55, 0.5, 0.42), wet * 0.8);
        float silt = 1.0 - smoothstep(-0.6, -0.1, wl);
        result = mix(result, to_linear(vec3(0.33, 0.36, 0.24)), silt * 0.7);
    }
    ALBEDO = result;
    ROUGHNESS = 0.95;
}
