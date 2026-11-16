shader_type spatial;
// The ground of Japan. Colours come per triangle from the vertices (sRGB, japan.gd's JCOL); this
// tells the kinds apart by colour and adds what shows close by, all procedural:
//   grass        soft patches, blades, small white, yellow and pink flowers, and a carpet of cherry
//                petals along the river (whose line the shader knows: river_x below)
//   forest       moss patches and fallen maple leaves, red and orange
//   rice         rows of young rice in the green paddies; the flooded ones mirror the sky
//   city         square paving slabs with joints, a shade per slab
//   stone        cobbles (old town, temple hill) with moss in the joints
//   rock         layered strata on the mountains, moss on what faces up
//   roadside     dusty gravel
//   waterline    dark wet mud along the river, the moat and the ponds
// Weather and season (world/atmosphere.gd) as on the other worlds: autumn, rain and snow.

global uniform float snow_amount;
global uniform float autumn_amount;
global uniform float wet_amount;

varying vec3 wpos;
varying vec3 wnormal;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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

// Distance to the nearest and second nearest cell centre (cobbles): x = d1, y = d2.
vec2 cells(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float d1 = 8.0;
    float d2 = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 o = vec2(hash2(i + g), hash2(i + g + 17.0)) * 0.8 + 0.1;
            float d = length(g + o - f);
            if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
        }
    }
    return vec2(d1, d2);
}

// The river's centre line (japan.gd: river_x) and its half width.
float river_x(float z) {
    return 300.0 + 28.0 * sin(z / 190.0 + 1.0);
}

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 srgb = COLOR.rgb;
    vec3 col = to_linear(srgb);
    float dist = length(VERTEX);
    float close = 1.0 - smoothstep(30.0, 130.0, dist);
    float near = 1.0 - smoothstep(8.0, 45.0, dist);
    float mx = max(srgb.r, max(srgb.g, srgb.b));
    float mn = min(srgb.r, min(srgb.g, srgb.b));
    float sat = mx - mn;
    float lum = dot(srgb, vec3(0.2126, 0.7152, 0.0722));
    float green = smoothstep(0.05, 0.11, srgb.g - srgb.r);
    float paddy_water = green * smoothstep(0.08, 0.14, srgb.b - srgb.r);
    float rice = green * (1.0 - paddy_water) * smoothstep(0.47, 0.51, srgb.r) * smoothstep(0.66, 0.70, srgb.g);
    float forest = green * (1.0 - rice) * (1.0 - paddy_water) * (1.0 - smoothstep(0.38, 0.46, lum));
    float grass = green * (1.0 - rice) * (1.0 - paddy_water) * (1.0 - forest);
    float grey = (1.0 - green) * (1.0 - smoothstep(0.04, 0.09, sat));
    float city = grey * smoothstep(-0.005, 0.015, srgb.b - srgb.r);
    float warm = (1.0 - green) * (1.0 - city) * step(0.6, wpos.y);
    float stone = warm * smoothstep(0.66, 0.70, lum);
    float rock = warm * (1.0 - stone) * smoothstep(0.8, 0.55, wnormal.y);
    float dusty = warm * (1.0 - stone) * (1.0 - rock);
    vec3 result = col;
    float rough = 0.93;

    if (grass > 0.001) {
        float patchy = fbm(wpos * 0.07 + 40.0);
        vec3 g = col * (0.82 + 0.36 * patchy);
        g = mix(g, g * vec3(1.12, 1.06, 0.7), step(0.64, noise(wpos * 1.5)) * 0.4);          // dry tufts
        float blades = noise(vec3(wpos.x * 9.0, 0.0, wpos.z * 1.2)) * noise(vec3(wpos.x * 1.1, 3.0, wpos.z * 9.0));
        g *= 1.0 - 0.18 * near * smoothstep(0.25, 0.6, blades);
        float bloom = step(0.94, noise(wpos * 7.5)) * close;                                    // flowers
        float pick = hash(floor(wpos * 7.5));
        vec3 flower = pick < 0.45 ? vec3(0.9, 0.9, 0.85) : (pick < 0.75 ? vec3(0.95, 0.8, 0.2) : vec3(0.95, 0.55, 0.7));
        g = mix(g, flower, bloom * 0.85);
        float dr = abs(wpos.x - river_x(wpos.z)) - 36.0;
        float petal_zone = (1.0 - smoothstep(0.0, 70.0, dr)) * step(0.0, dr + 2.0);
        float petals = step(0.84, noise(wpos * 8.0 + 7.0)) * petal_zone * close;
        g = mix(g, vec3(0.97, 0.66, 0.76), petals * 0.75);
        vec3 straw = mix(vec3(0.44, 0.31, 0.11), vec3(0.34, 0.15, 0.05), step(0.6, noise(wpos * 0.25)));
        g = mix(g, straw * (0.8 + 0.4 * patchy), autumn_amount * 0.8);
        result = mix(result, g, grass);
    }
    if (forest > 0.001) {
        vec3 f = col * (0.75 + 0.4 * fbm(wpos * 0.12 + 5.0));
        f = mix(f, to_linear(vec3(0.30, 0.42, 0.16)), smoothstep(0.55, 0.7, fbm(wpos * 0.3 + 11.0)) * 0.6);   // moss
        float leaf = step(0.9, noise(wpos * 6.0 + 3.0)) * close;
        float hue = hash(floor(wpos * 6.0 + 3.0));
        vec3 leaves = hue < 0.5 ? vec3(0.62, 0.14, 0.06) : vec3(0.75, 0.38, 0.08);
        f = mix(f, leaves, leaf * (0.7 + 0.3 * autumn_amount));
        f = mix(f, f * vec3(1.3, 0.8, 0.4), autumn_amount * 0.5);
        result = mix(result, f, forest);
    }
    if (rice > 0.001) {
        float rows = smoothstep(0.35, 0.65, abs(fract(wpos.z / 0.42) - 0.5) * 2.0);
        vec3 r = mix(col * 1.1, col * vec3(0.5, 0.55, 0.45), rows * near * 0.8 + rows * close * 0.2);
        r *= 0.9 + 0.2 * fbm(wpos * 0.1);
        r = mix(r, vec3(0.62, 0.48, 0.18), autumn_amount * 0.8);                                   // ripe
        result = mix(result, r, rice);
    }
    if (paddy_water > 0.001) {
        vec2 hill = vec2(fract(wpos.x / 0.3) - 0.5, fract(wpos.z / 0.42) - 0.5);
        float seedlings = 1.0 - smoothstep(0.1, 0.18, length(hill));                              // tufts in rows
        vec3 w = col * vec3(0.5, 0.6, 0.62) * (0.8 + 0.2 * fbm(wpos * 0.2));
        w = mix(w, to_linear(vec3(0.38, 0.58, 0.26)), seedlings * near * 0.6);
        result = mix(result, w, paddy_water);
        rough = mix(rough, 0.22, paddy_water * (1.0 - seedlings * near));                          // glints of sky
    }
    if (city > 0.001) {
        vec2 slab = wpos.xz / 1.2;
        vec2 fs = abs(fract(slab) - 0.5);
        float joint = smoothstep(0.46, 0.49, max(fs.x, fs.y)) * close;
        float shade = 0.9 + 0.16 * hash2(floor(slab));
        vec3 c = col * shade * (0.92 + 0.12 * fbm(wpos * 0.15));
        c = mix(c, c * 0.62, joint);
        c *= 1.0 - 0.15 * step(0.75, noise(wpos * 0.6)) * close;                                  // stains
        result = mix(result, c, city);
        rough = mix(rough, 0.8, city);
    }
    if (stone > 0.001) {
        vec2 cc = cells(wpos.xz * 2.2);
        float edge = smoothstep(0.0, 0.12, cc.y - cc.x);
        vec3 s = col * (0.82 + 0.3 * hash2(floor(wpos.xz * 2.2 + 0.5)));
        vec3 moss = to_linear(vec3(0.32, 0.40, 0.2));
        s = mix(mix(s * 0.55, moss, 0.35), s, mix(edge, 1.0, 1.0 - close));
        result = mix(result, s, stone);
    }
    if (rock > 0.001) {
        float strata = sin(wpos.y * 2.4 + fbm(wpos * 0.15) * 4.0) * 0.5 + 0.5;
        vec3 k = col * (0.8 + 0.25 * strata) * (0.85 + 0.3 * fbm(wpos * 0.25));
        k = mix(k, to_linear(vec3(0.3, 0.38, 0.2)), smoothstep(0.55, 0.85, wnormal.y) * 0.5);
        result = mix(result, k, rock);
    }
    if (dusty > 0.001) {
        vec3 d = col * (0.88 + 0.2 * fbm(wpos * 0.2));
        d *= 0.9 + 0.2 * step(0.7, noise(wpos * 9.0)) * near;                                    // pebbles
        result = mix(result, d, dusty);
    }
    if (wpos.y < 1.2) {
        float ragged = (fbm(wpos * 0.8 + 3.0) - 0.5) * 0.4;
        float wl = wpos.y + ragged;
        float wet = 1.0 - smoothstep(0.1, 0.8, wl);
        result = mix(result, result * vec3(0.5, 0.48, 0.42), wet * 0.8);
        rough = mix(rough, 0.4, wet * 0.6);
    }
    result *= 1.0 - 0.35 * wet_amount;
    rough = mix(rough, 0.45, wet_amount);
    if (snow_amount > 0.0) {
        float lie = smoothstep(0.5, 0.85, wnormal.y + (fbm(wpos * 0.45 + 9.0) - 0.5) * 0.55);
        vec3 snow = mix(vec3(0.66, 0.71, 0.80), vec3(0.80, 0.82, 0.87), noise(wpos * 1.3));
        result = mix(result, snow, snow_amount * lie * (1.0 - paddy_water * 0.6));
        rough = mix(rough, 0.75, snow_amount * lie);
    }
    ALBEDO = result;
    ROUGHNESS = rough;
}
