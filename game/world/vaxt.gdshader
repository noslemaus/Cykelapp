shader_type spatial;
// Plants and trees with their colours in the vertices (sRGB), swaying gently in the wind. The sway
// grows with height above the model's foot: linearly for trees (the crown moves, the trunk
// barely), with the square for grass and flowers (the tips move most). Each instance gets its own
// phase from where it stands, so a meadow ripples instead of moving in step.

// Seasons (world/atmosphere.gd): leaves turn yellow, orange and red in autumn and fall in winter;
// grass and flowers go under the snow; snow lies on what faces up.
global uniform float snow_amount;
global uniform float autumn_amount;
uniform float leafy = 0.0;           // 1: a broadleaf tree (its green turns and falls), 0: conifers
uniform float ground_plant = 0.0;    // 1: grass, flowers and shrubs (hidden under the winter snow)

varying vec3 wn;
varying float pick;

uniform float sway_linear = 0.0;     // metres of sway per metre of height
uniform float sway_square = 0.0;     // metres of sway per square metre of height
uniform float roughness_value = 0.85;

vec3 to_linear(vec3 c) {
    return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
    vec3 foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float h = max(VERTEX.y, 0.0);
    float phase = foot.x * 0.13 + foot.z * 0.17;
    float gust = 0.75 + 0.25 * sin(TIME * 0.35 + foot.x * 0.01);
    float s = (sin(TIME * 1.3 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.9) * 0.3) * gust;
    float amount = sway_linear * h + sway_square * h * h;
    VERTEX.x += s * amount;
    VERTEX.z += cos(TIME * 1.1 + phase * 1.3) * amount * 0.45;
    wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    pick = fract(foot.x * 0.731 + foot.z * 0.379);
    // Under the snow: small plants shrink into the ground.
    VERTEX *= 1.0 - ground_plant * smoothstep(0.35, 0.75, snow_amount);
}

void fragment() {
    vec3 c = to_linear(COLOR.rgb);
    float leaf = smoothstep(0.02, 0.09, COLOR.g - max(COLOR.r, COLOR.b));
    float turns = max(leafy, ground_plant);
    if (leafy > 0.5 && leaf > 0.5 && snow_amount > 0.5) {
        discard;     // winter: bare branches
    }
    // Autumn colours, one per tree (birches yellow, rowans red …), keeping the leaves' light and dark.
    vec3 fall = mix(vec3(0.95, 0.62, 0.08), vec3(0.88, 0.30, 0.05), smoothstep(0.35, 0.7, pick));
    fall = mix(fall, vec3(0.62, 0.08, 0.05), smoothstep(0.8, 0.95, pick));
    if (ground_plant > 0.5) {
        fall = vec3(0.62, 0.44, 0.16);
    }
    float shade = clamp(dot(c, vec3(0.2126, 0.7152, 0.0722)) / 0.12, 0.45, 1.4);
    c = mix(c, to_linear(fall) * shade, leaf * turns * autumn_amount);
    float on_top = smoothstep(0.35, 0.8, wn.y);
    c = mix(c, vec3(0.74, 0.77, 0.84), snow_amount * on_top * 0.85);
    ALBEDO = c;
    ROUGHNESS = roughness_value;
}
