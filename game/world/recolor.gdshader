shader_type spatial;
// A painted part (jersey, frame) in a new colour: the texture's light and dark detail is kept and
// laid over the new colour, so the fabric still looks like fabric.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool has_tex = true;
uniform vec3 target : source_color = vec3(1.0);
uniform float ref_lum = 0.2;     // the original colour's brightness (linear)
uniform float roughness_value = 0.7;

void fragment() {
    float detail = 1.0;
    if (has_tex) {
        vec3 c = texture(tex, UV).rgb;
        detail = clamp(dot(c, vec3(0.2126, 0.7152, 0.0722)) / max(ref_lum, 0.01), 0.62, 1.15);
    }
    ALBEDO = target * detail;
    ROUGHNESS = roughness_value;
}
