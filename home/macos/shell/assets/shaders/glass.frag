#version 440
// Plaque "Liquid Glass" (macOS Tahoe) dessinée en une passe à partir d'une SDF
// de rectangle arrondi : teinte, lueur interne d'épaisseur, liseré spéculaire
// (dépend de l'orientation du bord par rapport à la lumière), ombre portée
// analytique (gaussienne) limitée à l'extérieur de la plaque.
//
// Recompiler après modification (qsb de qtshadertools, même version que Qt) :
//   qsb --qt6 -o glass.frag.qsb glass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;       // taille de l'item shader (px logiques)
    vec4 plate;          // x, y, w, h de la plaque dans l'item
    float radius;
    vec4 tint;           // teinte (non prémultipliée)
    vec4 rimColor;       // couleur du liseré
    float rimWidth;      // épaisseur du liseré (px)
    float rimBase;       // intensité du liseré hors zones éclairées (0..1)
    vec4 glowColor;      // lueur interne près des bords
    float glowWidth;     // largeur de la lueur (px)
    vec4 shadowColor;
    float shadowSigma;   // écart-type de l'ombre (px), 0 = pas d'ombre
    float shadowOffsetY;
    vec2 lightDir;       // direction (normalisée) vers laquelle va la lumière
    float shadowMax;     // alpha max de l'ombre (reste sous le seuil ignore_alpha
                         // de Hyprland, 0.05 : sinon le fond sous l'ombre serait
                         // flouté et un halo net apparaîtrait autour du verre)
    vec4 shadeColor;     // bande sombre interne (réfraction dans l'épaisseur)
    float shadeWidth;    // largeur de cette bande (px)
};

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Approximation de erf (Abramowitz & Stegun 7.1.26)
float erfApprox(float x) {
    float s = sign(x);
    x = abs(x);
    float t = 1.0 / (1.0 + 0.3275911 * x);
    float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
    return s * y;
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 hs = plate.zw * 0.5;
    vec2 c = plate.xy + hs;
    float r = min(radius, min(hs.x, hs.y));
    vec2 p = px - c;

    float d = sdRoundBox(p, hs, r);
    float fw = max(fwidth(d), 1e-4);
    float cov = clamp(0.5 - d / fw, 0.0, 1.0);

    // Normale du bord (gradient de la SDF)
    const float e = 0.5;
    vec2 n = vec2(sdRoundBox(p + vec2(e, 0.0), hs, r) - sdRoundBox(p - vec2(e, 0.0), hs, r),
                  sdRoundBox(p + vec2(0.0, e), hs, r) - sdRoundBox(p - vec2(0.0, e), hs, r));
    n = normalize(n + vec2(1e-6));
    // Lumière venant du haut à gauche ; le bord opposé (bas droite) reçoit un
    // reflet plus faible (lumière qui traverse le verre), comme sur Tahoe.
    float l = dot(n, -lightDir);
    float lit = pow(max(l, 0.0), 1.5) + 0.75 * pow(max(-l, 0.0), 1.8);

    // Teinte
    vec4 col = vec4(tint.rgb * tint.a, tint.a);

    float inside = max(-d, 0.0);

    // Bande sombre juste sous le liseré : sur Tahoe, l'épaisseur du verre
    // réfracte (comprime) le fond près des bords, ce qui assombrit un liseré
    // intérieur de quelques px, surtout côté opposé à la lumière.
    float sb = 1.0 - smoothstep(rimWidth * 0.5, max(shadeWidth, rimWidth + 0.5), inside);
    sb = sb * sb * (0.45 + 0.55 * max(-l, 0.0) + 0.25 * (1.0 - abs(l)));
    vec4 shade = vec4(shadeColor.rgb * shadeColor.a, shadeColor.a) * sb;
    col = shade + col * (1.0 - shade.a);

    // Lueur interne (épaisseur du verre), plus forte côté lumière
    float g = 1.0 - smoothstep(0.0, max(glowWidth, 0.001), inside);
    g = g * g * (0.25 + 0.75 * lit);
    vec4 glow = vec4(glowColor.rgb * glowColor.a, glowColor.a) * g;
    col = glow + col * (1.0 - glow.a);

    // Liseré spéculaire
    float rimMask = 1.0 - smoothstep(rimWidth - 0.5 * fw, rimWidth + 0.5 * fw, inside);
    float ri = rimMask * mix(rimBase, 1.0, lit);
    vec4 rim = vec4(rimColor.rgb * rimColor.a, rimColor.a) * ri;
    col = rim + col * (1.0 - rim.a);

    col *= cov;

    // Ombre : flou gaussien d'un rectangle arrondi (approx. par erf de la SDF),
    // uniquement hors de la plaque pour ne pas assombrir le verre translucide.
    if (shadowSigma > 0.0) {
        float ds = sdRoundBox(p - vec2(0.0, shadowOffsetY), hs, r);
        float sh = 0.5 * (1.0 - erfApprox(ds / (shadowSigma * 1.41421356)));
        // Profil gaussien ramené sous shadowMax (pas d'écrêtage : un plateau
        // écrêté dessinerait une bande uniforme autour du verre).
        float sa = min(shadowColor.a, shadowMax) * min(1.0, 2.0 * sh) * (1.0 - cov);
        col += vec4(shadowColor.rgb * sa, sa);
    }

    fragColor = col * qt_Opacity;
}
