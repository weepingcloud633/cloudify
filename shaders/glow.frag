#version 440
// a soft radial glow in one colour, behind the cover
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
    float intensity;
};
void main()
{
    float d = length((qt_TexCoord0 - 0.5) * 2.0);
    float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.4) * intensity;
    fragColor = vec4(color.rgb * a, a) * qt_Opacity;
}
