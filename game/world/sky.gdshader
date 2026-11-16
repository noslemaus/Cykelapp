shader_type sky;
render_mode use_debanding;
// Sunset sky like the concept art: lavender-blue overhead, peach along the horizon, warm gold on
// the side of the low sun, a soft glow and a bright disc. Also lights the scene (ambient and
// reflections come from this sky).

uniform vec3 zenith_color : source_color = vec3(0.38, 0.46, 0.80);
uniform vec3 high_color : source_color = vec3(0.70, 0.62, 0.88);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.68, 0.56);
uniform vec3 sun_side_color : source_color = vec3(1.0, 0.70, 0.34);
uniform vec3 ground_color : source_color = vec3(0.22, 0.28, 0.42);
uniform float sun_size = 0.03;
uniform float energy = 1.0;
// Weather and time of day (world/atmosphere.gd): grey overcast that hides the sun, stars at night
// and the disc's colour (the moon is white-blue).
uniform float overcast = 0.0;
uniform vec3 overcast_color : source_color = vec3(0.62, 0.65, 0.70);
uniform float stars = 0.0;
uniform vec3 disc_color = vec3(1.0, 0.92, 0.72);

float star_hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
    vec3 d = EYEDIR;
    // Below the horizon (only ever seen in reflections, the sea covers it) mirror the sky above,
    // so rippled water reflects warm horizon light instead of a dark ground.
    float h = abs(d.y);
    float cos_sun = LIGHT0_ENABLED ? dot(d, LIGHT0_DIRECTION) : 0.0;
    float sd = max(cos_sun, 0.0);
    // Vertical gradient: peach horizon, lavender band, blue overhead.
    vec3 col = mix(horizon_color, high_color, smoothstep(0.0, 0.3, h));
    col = mix(col, zenith_color, smoothstep(0.28, 0.95, h));
    // The half of the sky facing the sun turns gold, most strongly near the horizon.
    float side = pow(sd, 2.5) * (1.0 - smoothstep(-0.05, 0.55, h));
    col = mix(col, sun_side_color, side * 0.9);
    // Glow round the sun and the disc itself (left out of the lighting pass so it does not
    // overpower the ambient light).
    col += sun_side_color * (pow(sd, 40.0) * 0.55 + pow(sd, 600.0) * 2.0) * (1.0 - overcast);
    if (!AT_CUBEMAP_PASS) {
        float disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), cos_sun) * (1.0 - overcast);
        col = mix(col, disc_color * 5.0, disc);
        if (stars > 0.0) {
            float s = star_hash(floor(d * 360.0));
            float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + s * 60.0);
            col += vec3(0.9, 0.93, 1.0) * step(0.9975, s) * (s - 0.9975) * 2400.0 * twinkle * stars
                * smoothstep(0.04, 0.3, d.y) * (1.0 - overcast);
        }
    }
    // Overcast: a grey lid, a little lighter towards the horizon.
    vec3 lid = overcast_color * mix(1.08, 0.82, smoothstep(0.0, 0.8, h));
    col = mix(col, lid, overcast);
    col = mix(col, ground_color, smoothstep(0.0, -0.6, d.y) * 0.35);
    COLOR = col * energy;
}
