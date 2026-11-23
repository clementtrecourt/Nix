#version 440
// Flou gaussien séparable (une direction par passe) du fond réfracté par
// LiquidGlass. Le résultat est mis en cache par un ShaderEffectSource : il
// n'est recalculé que si le fond ou la géométrie du verre change, jamais à
// chaque image.
//
// Échantillonnage bilinéaire « deux texels par lecture » : un noyau de rayon
// 3 sigma ne coûte que ~1,5 sigma lectures.
//
// Recompiler : qsb --qt6 -o liquidglass_blur.frag.qsb liquidglass_blur.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texelStep;   // pas d'un texel dans la direction du flou (coord. de texture)
    float sigma;      // écart-type en texels (0 = copie)
};

layout(binding = 1) uniform sampler2D source;

float gauss(float x) { return exp(-0.5 * x * x / (sigma * sigma)); }

void main() {
    vec2 uv = qt_TexCoord0;
    if (sigma < 0.3) {
        fragColor = texture(source, uv) * qt_Opacity;
        return;
    }
    int radius = int(ceil(3.0 * sigma));
    vec4 acc = texture(source, uv);
    float wsum = 1.0;
    // Paires de texels (i, i+1) lues en une seule fois au barycentre pondéré
    for (int i = 1; i <= 64; i += 2) {
        if (i > radius) break;
        float w1 = gauss(float(i));
        float w2 = gauss(float(i + 1));
        float w = w1 + w2;
        float o = (float(i) * w1 + float(i + 1) * w2) / w;
        acc += (texture(source, uv + texelStep * o) + texture(source, uv - texelStep * o)) * w;
        wsum += 2.0 * w;
    }
    fragColor = acc / wsum * qt_Opacity;
}
