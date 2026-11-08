#version 440
// Edge light for a Liquid Glass surface (components/GlassSheen.qml): one
// anti-aliased hairline around a rounded rectangle whose brightness fades
// smoothly from the top edge down the sides, plus a faint even edge all
// round. One continuous ring, so the light never stops at a hard step.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // item size, logical px
    float radius;   // corner radius, px
    vec4 light;     // the top light, straight alpha
    vec4 edge;      // the even edge all round, straight alpha
    float reach;    // how far down (0..1 of the height) the light fades out
};

float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 h = size * 0.5;
    float r = min(radius, min(h.x, h.y));
    float d = box(p - h, h - 0.5, r);       // 0 on the hairline's centre
    float aa = max(fwidth(d), 0.0001);
    float line = 1.0 - smoothstep(0.5 - aa * 0.5, 0.5 + aa, abs(d));
    if (line <= 0.0) { fragColor = vec4(0.0); return; }

    // Top light: full along the top, easing out down the sides.
    float y = qt_TexCoord0.y / max(reach, 0.01);
    float fall = 1.0 - smoothstep(0.0, 1.0, y);
    fall *= fall;
    float a = clamp(edge.a * (1.0 - fall * light.a) + light.a * fall, 0.0, 1.0);
    vec3 rgb = a > 0.0 ? (edge.rgb * edge.a * (1.0 - fall * light.a) + light.rgb * light.a * fall) / a : vec3(0.0);
    fragColor = vec4(rgb * a, a) * line * qt_Opacity;
}
