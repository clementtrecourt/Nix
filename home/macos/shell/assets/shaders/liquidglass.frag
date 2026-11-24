#version 440
// Liquid Glass (macOS Tahoe 26) en une passe, à partir de la SDF d'un
// rectangle arrondi :
//  - lentille : la bande de bord (`bezel` px) est un biseau convexe (profil
//    « squircle » h = (1-(1-t)^4)^(1/4)) ; le rayon vertical y est dévié selon
//    la loi de Snell (n = 1,5) et lit le fond plus loin vers l'intérieur : le
//    fond est étiré vers le bord, comme sous une loupe. Le centre (t = 1) est
//    plat : aucune déformation ;
//  - dispersion : R, V, B lus à des déplacements légèrement différents (n
//    dépend de la longueur d'onde), uniquement là où il y a déplacement ;
//  - fond flouté (texture `bg`, déjà floutée et mise en cache par
//    LiquidGlass.qml), légèrement resaturé, puis teinte adaptative : la
//    teinte s'épaissit quand le fond contraste trop avec l'apparence ;
//  - liseré spéculaire dépendant de l'angle (lumière en haut à gauche, reflet
//    plus faible au coin opposé), lueur interne d'épaisseur ;
//  - ombre portée gaussienne analytique, hors de la plaque seulement.
// Sans fond (hasBg = 0) : teinte translucide seule (repli : flou Hyprland).
//
// NB : Qt passe les propriétés `color` d'un ShaderEffect en RGBA PRÉMULTIPLIÉ
// (rgb déjà multiplié par a) : elles sont utilisées telles quelles ici.
//
// Recompiler : qsb --qt6 -o liquidglass.frag.qsb liquidglass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;       // taille de l'item shader (px logiques)
    vec4 plate;          // x, y, w, h de la plaque dans l'item
    float radius;
    vec4 tint;           // teinte (couleurs QML : Qt les passe PRÉMULTIPLIÉES)
    vec4 bgRect;         // rectangle couvert par la texture `bg` (repère de l'item)
    float hasBg;         // 1 = réfraction du fond ; 0 = repli teinte seule
    float bezel;         // largeur de la bande de lentille (px)
    float refraction;    // déplacement max (px) ; > 0 : lit vers l'intérieur
    float dispersion;    // écart relatif R/B (0 = pas d'aberration chromatique)
    float saturation;    // saturation du fond (1 = neutre)
    float adaptive;      // 0..1 : renfort de teinte selon la luminance du fond
    float darkMode;      // 1 = apparence sombre
    float dim;           // voile noir (HIG : 35 % pour le « clear » sur fond clair)
    vec4 rimColor;       // couleur du liseré spéculaire
    float rimWidth;      // épaisseur du liseré (px)
    float rimBase;       // intensité du liseré hors zones éclairées (0..1)
    vec4 glowColor;      // lueur interne (épaisseur du verre)
    float glowWidth;     // largeur de la lueur (px)
    vec4 shadeColor;     // assombrissement interne sous le liseré
    float shadeWidth;
    vec4 shadowColor;
    float shadowSigma;   // écart-type de l'ombre (px), 0 = pas d'ombre
    float shadowOffsetY;
    float shadowMax;     // alpha max de l'ombre
    vec2 lightDir;       // direction (normalisée) dans laquelle va la lumière
    float edgeWidth;     // largeur de la bande d'épaisseur (px)
    float edgeDarken;    // assombrissement max dans la bande (0..1)
    float edgeSaturate;  // renfort de chrominance dans la bande
    vec4 overlay;        // voile composé PAR-DESSUS le fond réfracté (alpha normal, prémultiplié)
};

layout(binding = 1) uniform sampler2D bg;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float erfApprox(float x) {
    float s = sign(x);
    x = abs(x);
    float t = 1.0 / (1.0 + 0.3275911 * x);
    float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
    return s * y;
}

// Déviation d'un rayon vertical à travers le biseau, t = 0 au bord, 1 à la fin
// de la bande ; profil squircle convexe (pente infinie au bord, nulle à
// l'intérieur), Snell air -> verre (n = 1,5). Renvoie tan(theta1 - theta2)
// normalisé à 1 au bord : déplacement maximal sur le pixel du bord, qui
// décroît vite (fond comprimé et inversé dans la bande, centre intact).
float lens(float t) {
    const float n = 1.5;
    float u = 1.0 - clamp(t, 0.0, 1.0);
    float a = max(1.0 - u * u * u * u, 1e-5);
    float dh = u * u * u * pow(a, -0.75);
    float th1 = atan(dh);
    float th2 = asin(sin(th1) / n);
    return tan(th1 - th2) / 1.1180;   // tan(90° - asin(1/1,5))
}

vec3 sampleBg(vec2 p) {
    vec2 uv = (p - bgRect.xy) / bgRect.zw;
    return texture(bg, clamp(uv, vec2(0.0005), vec2(0.9995))).rgb;
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 hs = plate.zw * 0.5;
    vec2 c = plate.xy + hs;
    float r = min(radius, min(hs.x, hs.y));
    vec2 p = px - c;

    float d = sdRoundBox(p, hs, r);
    float fw = max(fwidth(d), 1e-4);
    float cov = clamp(0.5 - d / fw, 0.0, 1.0);

    // Normale sortante (gradient de la SDF). Sur l'axe médian du rectangle (taille
    // impaire : centre de pixel pile sur la crête), les différences centrées
    // s'annulent : on décale très légèrement le point d'évaluation pour briser
    // la symétrie, et on garde une normale de repli si le gradient reste nul.
    const float e = 0.5;
    vec2 pn = p + vec2(0.0131, 0.0173);
    vec2 n = vec2(sdRoundBox(pn + vec2(e, 0.0), hs, r) - sdRoundBox(pn - vec2(e, 0.0), hs, r),
                  sdRoundBox(pn + vec2(0.0, e), hs, r) - sdRoundBox(pn - vec2(0.0, e), hs, r));
    n = dot(n, n) > 1e-10 ? normalize(n) : vec2(0.0, -1.0);
    float l = dot(n, -lightDir);
    // Reflet spéculaire concentré : Tahoe allume nettement l'arc haut-gauche
    // et l'arc bas-droite, les flancs restent presque éteints.
    float lit = pow(max(l, 0.0), 2.6) + 0.8 * pow(max(-l, 0.0), 3.0);

    float inside = max(-d, 0.0);
    vec4 col = vec4(0.0);
    vec3 g = vec3(0.0);

    if (cov > 0.0) {
        if (hasBg > 0.5) {
            // ---- Lentille de bord ----
            float bz = max(bezel, 1.0);
            float t = inside / bz;
            float disp = refraction * lens(t);
            vec2 q = px - n * disp;
            if (dispersion > 0.0 && disp > 0.05) {
                // Le rouge est moins dévié que le bleu
                g.r = sampleBg(px - n * disp * (1.0 - dispersion)).r;
                g.g = sampleBg(q).g;
                g.b = sampleBg(px - n * disp * (1.0 + dispersion)).b;
            } else {
                g = sampleBg(q);
            }
            // ---- Matériau : luminance compressée, chrominance renforcée ----
            // Relevé sur Tahoe (Dock et modules du Control Center, clair) : la
            // luminance du fond flouté est ramenée vers celle de la teinte
            // (L' = 0,59 L + 0,27 : 45 -> 95, 90 -> 121, 150 -> 157 sur 255)
            // mais la couleur n'est pas délavée : la chrominance est conservée,
            // voire renforcée (vibrance). On travaille donc en luma/chroma.
            float L = luma(g);
            vec3 chroma = g - vec3(L);
            vec3 trgb = tint.a > 0.0 ? tint.rgb / tint.a : vec3(0.0);
            float tL = luma(trgb);

            // Teinte adaptative : plus de contraste fond/apparence -> plus de
            // compression (lisibilité), comme le « dynamic range shift » d'Apple.
            float contrast = mix(1.0 - L, L, darkMode);
            float ta = clamp(tint.a + adaptive * max(contrast - 0.7, 0.0), 0.0, 0.96);

            float L2 = mix(L, tL, ta);
            vec3 c2 = vec3(L2) + chroma * saturation * (1.0 - 0.5 * ta)
                    + (trgb - vec3(tL)) * ta;          // chrominance propre de la teinte
            // ---- Épaisseur du verre ----
            // Près du bord, la lumière traverse plus de verre : le fond y est
            // plus sombre et plus saturé (bande brune sur le beige, violette sur
            // le violet, relevée sur le Control Center de Tahoe), sauf sous les
            // arcs éclairés où le reflet domine.
            // Filet serré juste sous le liseré (biseau), puis fondu court.
            float eb = 1.0 - smoothstep(rimWidth * 0.6, max(edgeWidth, rimWidth + 1.0), inside);
            eb = pow(eb, 1.6) * (1.0 - 0.5 * lit);
            float L3 = luma(c2);
            c2 = vec3(L3) + (c2 - vec3(L3)) * (1.0 + edgeSaturate * eb);
            c2 *= 1.0 - edgeDarken * eb;
            col = vec4(clamp(c2, 0.0, 1.0), 1.0);
        } else {
            col = tint;
        }

        // Voile « overlay » (menus, notifications : teinte dense posée sur le fond)
        col = overlay + col * (1.0 - overlay.a);

        col = vec4(0.0, 0.0, 0.0, dim) + col * (1.0 - dim);

        // Bande sombre sous le liseré (épaisseur du verre côté ombre)
        float sb = 1.0 - smoothstep(rimWidth * 0.5, max(shadeWidth, rimWidth + 0.5), inside);
        sb = sb * sb * (0.45 + 0.55 * max(-l, 0.0) + 0.25 * (1.0 - abs(l)));
        vec4 shade = shadeColor * sb;
        col = shade + col * (1.0 - shade.a);

        // Lueur interne, plus forte côté lumière
        float gl = 1.0 - smoothstep(0.0, max(glowWidth, 0.001), inside);
        gl = gl * gl * (0.06 + 0.94 * lit);
        vec4 glow = glowColor * gl;
        col = glow + col * (1.0 - glow.a);

        // Liseré spéculaire
        float rimMask = 1.0 - smoothstep(rimWidth - 0.5 * fw, rimWidth + 0.5 * fw, inside);
        float ri = rimMask * mix(rimBase, 1.0, lit);
        // Le reflet est de la lumière du fond renvoyée par l'arête : il prend
        // sa couleur (relevé Tahoe : liseré rosé sur fond rose, bleuté sur bleu).
        vec3 rimRgb = rimColor.a > 0.0 ? rimColor.rgb / rimColor.a : vec3(1.0);
        if (hasBg > 0.5) rimRgb = mix(rimRgb, clamp(g * 1.6 + 0.25, 0.0, 1.0), 0.35);
        vec4 rim = vec4(rimRgb, 1.0) * rimColor.a * ri;
        col = rim + col * (1.0 - rim.a);

        col *= cov;
    }

    // Ombre portée hors de la plaque
    if (shadowSigma > 0.0) {
        float ds = sdRoundBox(p - vec2(0.0, shadowOffsetY), hs, r);
        float sh = 0.5 * (1.0 - erfApprox(ds / (shadowSigma * 1.41421356)));
        float sa = min(shadowColor.a, shadowMax) * min(1.0, 2.0 * sh) * (1.0 - cov);
        vec3 srgb = shadowColor.a > 0.0 ? shadowColor.rgb / shadowColor.a : vec3(0.0);
        col += vec4(srgb * sa, sa);
    }

    if (any(isnan(col)) || any(isinf(col))) col = vec4(0.0);
    fragColor = col * qt_Opacity;
}
