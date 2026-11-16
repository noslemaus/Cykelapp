shader_type spatial;
// Low-poly sea like the concept art:
//   clear shallows  the rocks and sand below show through (with a little refraction), tinted
//                   turquoise, fading to deep blue further out (from the scene depth behind)
//   reflections     houses, boats, rocks and islands are mirrored by marching the reflected ray
//                   through the depth buffer; where nothing is hit the sky is reflected instead
//   glitter         triangular facets, each tilted a little, catch the low sun as a glittering path
//   foam            a white line where the water meets rock
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

// Winter (world/atmosphere.gd): ice over the shallows and the sounds, open dark water further out.
global uniform float ice_amount;
global uniform float snow_amount;

uniform vec3 shallow : source_color = vec3(0.30, 0.84, 0.80);
uniform vec3 deep : source_color = vec3(0.10, 0.38, 0.52);
uniform float deep_energy = 0.75;
uniform vec3 foam_color : source_color = vec3(0.96, 0.97, 0.95);
uniform float depth_fade = 11.0;
uniform float wave_height = 0.14;
uniform float reflection_strength = 0.9;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float clip_radius = 0.0;        // > 0: only draw inside this circle (diorama)
uniform vec2 clip_center = vec2(0.0);
varying vec3 world_pos;

float waves(vec2 p, float t) {
    return sin(p.x * 0.11 + t * 0.9) * 0.5
         + sin(p.y * 0.13 - t * 0.7) * 0.35
         + sin((p.x + p.y) * 0.21 + t * 1.3) * 0.25;
}

void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_pos = world;
    VERTEX.y += waves(world.xz, TIME) * wave_height * (1.0 - ice_amount);
}

vec3 view_at(vec2 uv, sampler2D depth_tex, mat4 inv_proj) {
    float d = textureLod(depth_tex, uv, 0.0).r;
    vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
    return v.xyz / v.w;
}

void fragment() {
    if (clip_radius > 0.0 && distance(world_pos.xz, clip_center) > clip_radius) {
        discard;
    }
    // Normal: the faceted wave (low-poly look) leaned towards flat so reflections stay readable.
    vec3 facet = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
    vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    if (dot(facet, up_view) < 0.0) {
        facet = -facet;     // the derivative cross product can come out upside down
    }
    float dist = length(VERTEX);
    float t = TIME;
    // Triangular facets about 3.5 m across, each tilted a little and rocking slowly: the low-poly
    // water of the concept art. The tilt fades with distance so far water stays calm.
    vec2 g = world_pos.xz / 3.5;
    vec2 cell = floor(g);
    vec2 f = fract(g);
    vec2 id = cell * 2.0 + vec2(step(f.y, f.x), 0.0);
    float h1 = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
    float h2 = fract(sin(dot(id, vec2(269.5, 183.3))) * 43758.5453);
    vec2 tilt = vec2(sin(t * (0.6 + h1) + h2 * 6.28), cos(t * (0.5 + h2) + h1 * 6.28));
    tilt *= 0.035 * mix(1.0, 0.45, smoothstep(40.0, 260.0, dist));
    vec3 ripple = vec3(tilt.x, 0.0, tilt.y);
    vec3 n = normalize(mix(up_view, facet, 0.5) + (VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
    // Seen at a low angle a tilted ripple would face away from the eye and turn black; keep every
    // normal at least a little towards the viewer.
    vec3 to_eye = -normalize(VERTEX);
    float nv = dot(n, to_eye);
    if (nv < 0.12) {
        n = normalize(n + to_eye * (0.12 - nv));
    }
    NORMAL = n;

    // How much water lies between the surface and whatever is behind it.
    vec3 bg = view_at(SCREEN_UV, depth_texture, INV_PROJECTION_MATRIX);
    float thickness = max(VERTEX.z - bg.z, 0.0);
    float td = clamp(thickness / depth_fade, 0.0, 1.0);

    // Clear water: the scene behind, shifted a little by the facets where it is deep enough.
    vec2 refr_uv = SCREEN_UV + (VIEW_MATRIX * vec4(ripple, 0.0)).xy * 0.35 * clamp(thickness / 3.0, 0.0, 1.0);
    if (view_at(refr_uv, depth_texture, INV_PROJECTION_MATRIX).z > VERTEX.z) {
        refr_uv = SCREEN_UV;    // that sample is in front of the water: do not borrow it
    }
    vec3 behind = textureLod(screen_texture, refr_uv, 0.0).rgb;
    vec3 tinted = behind * mix(vec3(1.0), shallow * 1.3, clamp(thickness / 1.5, 0.0, 1.0));
    vec3 body = mix(tinted, deep * deep_energy, sqrt(td));

    // Reflection: march the mirrored ray through the depth buffer.
    vec3 view_dir = normalize(VERTEX);
    vec3 r = reflect(view_dir, n);
    vec3 refl = vec3(0.0);
    float hit = 0.0;
    // Only rays that rise in the world can mirror anything above the water (others would find
    // the sea floor, which shows through because the water writes no depth).
    if ((INV_VIEW_MATRIX * vec4(r, 0.0)).y > 0.01) {
        vec3 p = VERTEX;
        float stepl = 0.4 + dist * 0.012;
        for (int i = 0; i < 30; i++) {
            vec3 prev = p;
            p += r * stepl;
            vec4 c = PROJECTION_MATRIX * vec4(p, 1.0);
            vec2 uv = c.xy / c.w * 0.5 + 0.5;
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || p.z > -0.1) {
                break;
            }
            float sz = view_at(uv, depth_texture, INV_PROJECTION_MATRIX).z;
            if (p.z < sz && sz - p.z < stepl * 1.6 + 0.4) {
                // Refine between the last two points.
                vec3 lo = prev;
                vec3 hi = p;
                for (int k = 0; k < 5; k++) {
                    vec3 mid = (lo + hi) * 0.5;
                    vec4 cm = PROJECTION_MATRIX * vec4(mid, 1.0);
                    vec2 um = cm.xy / cm.w * 0.5 + 0.5;
                    if (mid.z < view_at(um, depth_texture, INV_PROJECTION_MATRIX).z) {
                        hi = mid;
                    } else {
                        lo = mid;
                    }
                }
                vec4 ch = PROJECTION_MATRIX * vec4(hi, 1.0);
                vec2 uh = ch.xy / ch.w * 0.5 + 0.5;
                float edge = smoothstep(0.0, 0.06, uh.x) * smoothstep(1.0, 0.94, uh.x)
                           * smoothstep(0.0, 0.06, uh.y) * smoothstep(1.0, 0.94, uh.y);
                if ((INV_VIEW_MATRIX * vec4(hi, 1.0)).y > -0.3) {
                    refl = textureLod(screen_texture, uh, 0.0).rgb;
                    hit = edge * (1.0 - float(i) / 30.0 * 0.5);
                }
                break;
            }
            stepl *= 1.16;
        }
    }
    float cos_v = clamp(dot(-view_dir, n), 0.0, 1.0);
    float fres = 0.04 + 0.96 * pow(1.0 - cos_v, 5.0);
    float foam = 1.0 - smoothstep(0.0, 0.6, thickness);

    ALBEDO = foam_color * foam * 0.8;
    EMISSION = (body * (1.0 - fres) + refl * fres * hit * reflection_strength) * (1.0 - foam * 0.85);
    // Godot adds the sky reflection and the sun's glint through the specular term; leave the
    // sky out where an object is mirrored already.
    SPECULAR = 0.5 * (1.0 - hit * 0.9);
    ROUGHNESS = 0.09;
    if (ice_amount > 0.0) {
        // Floes in big soft cells with dark cracks; thin water near land freezes first.
        vec2 q = world_pos.xz / 38.0;
        vec2 qc = floor(q);
        float floe = fract(sin(dot(qc, vec2(41.3, 289.1))) * 15731.7);
        float crack = smoothstep(0.0, 0.05, min(min(fract(q.x), 1.0 - fract(q.x)), min(fract(q.y), 1.0 - fract(q.y))));
        float frozen = ice_amount * smoothstep(0.3, 0.45, floe * 0.6 + (1.0 - sqrt(td)) * 0.75);
        float drift = fract(sin(dot(floor(world_pos.xz / 6.0), vec2(12.9, 78.2))) * 43758.5);
        vec3 ice_col = mix(vec3(0.66, 0.76, 0.84), vec3(0.90, 0.93, 0.97), step(0.55, drift) * snow_amount);
        ice_col *= mix(0.72, 1.0, crack);
        ALBEDO = mix(ALBEDO, ice_col, frozen);
        EMISSION = mix(EMISSION, vec3(0.0), frozen);
        SPECULAR = mix(SPECULAR, 0.35, frozen);
        ROUGHNESS = mix(ROUGHNESS, 0.32, frozen);
    }
    ALPHA = 1.0;
}
