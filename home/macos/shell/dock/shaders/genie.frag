#version 440
// Échantillonne la capture de la fenêtre (voir genie.vert).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float mode;
    vec4 src;
    vec4 dst;
    float radius;   // rayon des coins de la fenêtre (px)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    // Coins arrondis de la fenêtre (la capture est rectangulaire)
    vec2 p = qt_TexCoord0 * src.zw;
    vec2 q = abs(p - src.zw * 0.5) - (src.zw * 0.5 - vec2(radius));
    float d = length(max(q, 0.0)) - radius;
    float a = 1.0 - smoothstep(-0.75, 0.75, d);
    fragColor = texture(source, qt_TexCoord0) * qt_Opacity * a;
}
