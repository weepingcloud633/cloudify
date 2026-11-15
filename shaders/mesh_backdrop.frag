#version 440
// Cloud Music: a soft moving gradient field for the immersive player. Four colour blobs drift
// slowly and swell with the bass. Cheap on purpose: no noise, a handful of exp() per pixel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float time;
    vec4 energy;   // sub-bass, bass, upper bass, vocal (0..1)
    vec4 c0;       // ground
    vec4 c1;
    vec4 c2;
    vec4 c3;
};

float blob(vec2 p, vec2 c, float k) {
    vec2 d = p - c;
    return exp(-dot(d, d) * k);
}

void main() {
    float aspect = itemSize.x / max(itemSize.y, 1.0);
    vec2 p = vec2(qt_TexCoord0.x * aspect, qt_TexCoord0.y);
    float t = time;

    vec2 a = vec2(0.22 * aspect + 0.16 * sin(t * 0.13), 0.26 + 0.14 * cos(t * 0.11));
    vec2 b = vec2(0.82 * aspect + 0.18 * cos(t * 0.09), 0.22 + 0.16 * sin(t * 0.14));
    vec2 c = vec2(0.58 * aspect + 0.20 * sin(t * 0.08 + 2.0), 0.88 + 0.10 * cos(t * 0.12));
    vec2 d = vec2(0.08 * aspect + 0.10 * cos(t * 0.07 + 1.0), 0.80 + 0.10 * sin(t * 0.10));

    float wa = blob(p, a, 2.6 - energy.x * 0.9);
    float wb = blob(p, b, 2.4 - energy.y * 0.9);
    float wc = blob(p, c, 2.2 - energy.z * 0.7);
    float wd = blob(p, d, 3.0 - energy.w * 0.8);

    float ground = 0.30;
    vec3 col = (c0.rgb * ground + c1.rgb * wa + c2.rgb * wb + c3.rgb * wc + c1.rgb * wd * 0.8)
             / (ground + wa + wb + wc + wd * 0.8);

    // dark vignette keeps the edges calm and the text readable
    float v = smoothstep(1.15, 0.25, length(qt_TexCoord0 - vec2(0.5, 0.45)));
    col *= 0.62 + 0.38 * v;
    // a hair of dithering to avoid banding in the dark gradients
    float n = fract(sin(dot(qt_TexCoord0 * itemSize, vec2(12.9898, 78.233))) * 43758.5453);
    col += (n - 0.5) / 255.0;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
