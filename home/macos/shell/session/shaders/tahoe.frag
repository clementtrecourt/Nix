#version 440
// Fond d'écran procédural inspiré du fond par défaut de macOS Tahoe 26
// (l'original est une œuvre Apple non redistribuable : on en recrée la
// composition) :
//  - ciel en dégradé (bleu en haut -> lavande -> crème à l'horizon ; nuit
//    indigo -> violet en sombre) ;
//  - au loin à gauche, une butte turquoise floue et une bande d'eau bleu
//    profond ;
//  - une grande nappe de verre qui monte de bas-gauche vers haut-droite, lèvre
//    brillante très fine, épaisseur pâle aux larges ondulations floues, bord
//    inférieur en dents de scie adoucies, revers bleu intense ;
//  - au premier plan, des formes floues (dune pâle à gauche, sphère pâle à
//    droite, creux bleu nuit au centre).
// Coordonnées de référence : cadrage 16:10 d'une image carrée (comme macOS
// recadre l'original 6016x6016) ; les autres formats sont recadrés "cover".
// Compilé en .qsb par session/shaders/build.sh (qsb de qtshadertools).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;   // largeur / hauteur de l'écran
    float dark;     // 0 = clair, 1 = sombre (interpolé pour le fondu)
    float pxv;      // 1 pixel en unités de hauteur (1 / hauteur)
};

const float A = 1.6;   // format de référence

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec3 rgb(float r, float g, float b) { return vec3(r, g, b) / 255.0; }

// Ellipse floue : 1 au centre, 0 au-delà du bord (adoucissement `soft`)
float blob(vec2 p, vec2 c, vec2 r, float soft) {
    vec2 q = (p - c) / r;
    return 1.0 - smoothstep(1.0 - soft, 1.0 + soft, length(q));
}

// Lèvre de la nappe de verre : v = edge(u)
// (ajustée par moindres carrés sur la lèvre de l'original, cadrage 16:10)
float edge(float u) {
    return 0.45 - 0.53 * tanh((u - 0.37) / 0.34);
}

void main() {
    // ---- Recadrage "cover" vers les coordonnées 16:10 de référence ----
    vec2 uv = qt_TexCoord0;
    vec2 sq;  // coordonnées dans l'image carrée d'origine
    if (aspect >= 1.0) sq = vec2(uv.x, 0.5 + (uv.y - 0.5) / aspect);
    else sq = vec2(0.5 + (uv.x - 0.5) * aspect, uv.y);
    float u = sq.x;
    float v = (sq.y - 0.1875) / 0.625;
    vec2 P = vec2(u * A, v);                         // repère isotrope
    float px = pxv / (0.625 * max(aspect, 1.0));  // 1 px en unités de v
    float dk = dark;

    // ---- Ciel ----
    vec3 sL = mix(rgb(84, 166, 221), rgb(165, 189, 213), smoothstep(0.0, 0.11, v));
    sL = mix(sL, rgb(197, 201, 202), smoothstep(0.08, 0.21, v));
    sL = mix(sL, rgb(219, 211, 184), smoothstep(0.19, 0.34, v));
    sL = mix(sL, rgb(205, 212, 196), smoothstep(0.38, 0.52, v));
    vec3 sD = mix(rgb(4, 3, 82), rgb(30, 18, 156), smoothstep(0.0, 0.12, v));
    sD = mix(sD, rgb(60, 36, 193), smoothstep(0.09, 0.22, v));
    sD = mix(sD, rgb(88, 62, 206), smoothstep(0.2, 0.33, v));
    sD = mix(sD, rgb(104, 88, 207), smoothstep(0.34, 0.48, v));
    vec3 col = mix(sL, sD, dk);

    // ---- Lointain à gauche : butte turquoise + bande d'eau bleu profond ----
    float mound = blob(P, vec2(0.07 * A, 0.50), vec2(0.24, 0.07), 0.5);
    col = mix(col, mix(rgb(52, 146, 200), rgb(42, 64, 170), dk), mound * 0.95);
    float mound2 = blob(P, vec2(0.27 * A, 0.545), vec2(0.22, 0.04), 0.6);
    col = mix(col, mix(rgb(96, 170, 222), rgb(70, 72, 180), dk), mound2 * 0.7);
    float band = smoothstep(0.52, 0.58, v) * (1.0 - smoothstep(0.82, 0.92, v));
    vec3 bandC = mix(rgb(10, 99, 208), rgb(0, 38, 147), dk);
    vec3 bandCore = mix(rgb(0, 53, 193), rgb(0, 27, 125), dk);
    bandC = mix(bandC, bandCore, blob(P, vec2(0.20 * A, 0.62), vec2(0.28, 0.05), 0.6));
    // reflets horizontaux flous sur l'eau
    bandC += mix(vec3(0.10, 0.16, 0.12), vec3(0.06, 0.07, 0.14), dk)
           * smoothstep(0.3, 1.0, sin(v * 55.0 + u * 4.0 + 1.2 * sin(u * 11.0))) * (1.0 - smoothstep(0.0, 0.5, u)) * 0.7;
    col = mix(col, bandC, band);

    // ---- Nappe de verre ----
    float e = edge(u);
    float de = (edge(u + 0.002) - edge(u - 0.002)) / 0.004;
    float n = sqrt(1.0 + (de / A) * (de / A));
    float d = (v - e) / n;                       // distance (perpendiculaire) sous la lèvre
    float T = mix(0.035, 0.27, smoothstep(0.18, 0.80, u));   // épaisseur apparente
    float under = smoothstep(-px, px, d);        // 1 sous la lèvre

    // Fond bleu sous la nappe (corps de la vague)
    vec3 body = mix(rgb(10, 98, 208), rgb(0, 45, 164), dk);
    // colline claire sous le verre
    body = mix(body, mix(rgb(94, 170, 224), rgb(67, 107, 188), dk), blob(P, vec2(0.62 * A, 0.48), vec2(0.26, 0.11), 0.7));
    body = mix(body, mix(rgb(27, 119, 211), rgb(2, 59, 164), dk), blob(P, vec2(0.42 * A, 0.66), vec2(0.30, 0.12), 0.8) * 0.6);
    // creux bleu nuit en bas au centre
    body = mix(body, mix(rgb(0, 24, 131), rgb(0, 11, 88), dk), blob(P, vec2(0.60 * A, 1.02), vec2(0.42, 0.24), 0.6));
    // au bord gauche, la nappe est vue par la tranche : on voit l'eau derrière
    body = mix(body, bandC, (1.0 - smoothstep(0.05, 0.30, u)) * (1.0 - smoothstep(0.0, 0.08, d)) * 0.6);

    // Revers bleu intense (dessous de la vague), juste sous l'épaisseur de verre
    float curl = smoothstep(T - 0.02, T + 0.015, d) * (1.0 - smoothstep(T + 0.05, T + 0.14, d));
    body = mix(body, mix(rgb(0, 78, 214), rgb(0, 14, 100), dk), curl * smoothstep(0.35, 0.6, u));

    // Épaisseur du verre : translucide pâle, larges ondulations floues
    // parallèles à la lèvre (réfraction), plus claires près de la lèvre
    float t = clamp(d / T, 0.0, 1.0);
    vec3 glassL = mix(rgb(184, 214, 200), rgb(118, 176, 196), smoothstep(0.0, 0.9, t));
    vec3 glassD = mix(rgb(40, 52, 178), rgb(22, 40, 166), smoothstep(0.0, 0.7, t));
    vec3 glassC = mix(glassL, glassD, dk);
    // le ciel transparaît un peu à travers le verre
    glassC = mix(glassC, col, 0.12 * (1.0 - dk));
    float r1 = sin(t * 15.0 + u * 8.0 + 1.6 * sin(u * 5.0 + t * 2.0));
    float r2 = sin(t * 27.0 - u * 9.0 + 0.9 * sin(u * 13.0));
    float rip = 0.7 * r1 + 0.3 * r2;
    // ondulations : bandes bleues saturées (creux) / bandes claires
    // jaune-vert (crêtes), comme la réfraction de l'original
    vec3 ripBlue = mix(rgb(62, 140, 204), rgb(18, 34, 150), dk);
    glassC = mix(glassC, ripBlue, smoothstep(0.05, 0.95, -rip) * smoothstep(0.03, 0.25, t) * mix(0.85, 0.6, dk));
    glassC += mix(vec3(0.10, 0.10, 0.03), vec3(0.13, 0.13, 0.20), dk) * smoothstep(0.1, 1.0, rip) * (1.0 - 0.5 * t);
    // près de la lèvre : verre plus lumineux
    glassC = mix(glassC, mix(rgb(214, 236, 232), rgb(78, 96, 214), dk), (1.0 - smoothstep(0.0, 0.14, t)) * 0.30);
    // Bord inférieur du verre : dents de scie floues (vague brisée vue à travers)
    // (fréquence légèrement variable : dents irrégulières, comme l'original)
    // sinus déformé (asymétrique) plutôt que fract() : pas d'arête verticale
    float ph = 6.2832 * (u * 12.0 + 1.1 * sin(u * 7.0) - t * 0.9);
    float teeth = 0.5 + 0.5 * sin(ph + 0.9 * sin(ph));
    float saw = mix(0.84, 0.66 + 0.12 * teeth, smoothstep(0.6, 0.8, u));
    float sawMask = smoothstep(saw - 0.12, saw + 0.10, t);
    glassC = mix(glassC, mix(rgb(30, 92, 206), rgb(10, 28, 140), dk), sawMask * smoothstep(0.45, 0.65, u));
    float inGlass = (1.0 - smoothstep(T - 0.03, T + 0.01, d));
    vec3 below = mix(body, glassC, inGlass * smoothstep(0.15, 0.45, u + 0.2 * t));
    // côté gauche : verre fin et clair (bord de la nappe)
    below = mix(below, glassC, inGlass * (1.0 - smoothstep(0.15, 0.45, u)) * 0.55);

    // ---- Premier plan flou ----
    // dune pâle à gauche
    float dune = blob(P, vec2(0.20 * A, 1.07), vec2(0.60, 0.34), 0.5);
    vec3 duneC = mix(rgb(146, 182, 198), rgb(84, 100, 184), dk);
    duneC = mix(duneC, mix(rgb(96, 145, 172), rgb(60, 82, 163), dk), smoothstep(0.85, 1.0, v));
    below = mix(below, duneC, dune * 0.92 * smoothstep(0.0, 0.05, d));
    // sphère pâle à droite (bord net mais doux, éclairée en haut à gauche)
    vec2 sc = vec2(1.95, 1.25);
    float sr = 0.86;
    float sd = length(P - sc) - sr;
    float sph = 1.0 - smoothstep(-0.006, 0.006, sd);
    vec2 sn = normalize(P - sc);
    float lit = clamp(dot(sn, normalize(vec2(-0.8, -0.6))), 0.0, 1.0);
    vec3 sphC = mix(mix(rgb(104, 142, 182), rgb(150, 184, 206), lit), mix(rgb(80, 94, 160), rgb(112, 126, 186), lit), dk);
    sphC = mix(sphC, mix(rgb(205, 225, 234), rgb(150, 165, 222), dk), exp(-abs(sd) / 0.012) * 0.6 * lit);
    sphC += (hash(floor(P * 900.0)) - 0.5) * 0.025;   // grain de la surface
    below = mix(below, sphC, sph);
    // halo bleuté autour de la sphère (profondeur de champ)
    below = mix(below, sphC, (1.0 - sph) * exp(-max(sd, 0.0) / 0.02) * 0.25);

    col = mix(col, below, under);

    // ---- Lèvre brillante de la nappe ----
    float ad = abs(d);
    float lip = exp(-ad / (1.0 * px)) * mix(0.8, 0.95, dk)
              + exp(-max(d, 0.0) / 0.006) * under * 0.35
              + exp(-max(-d, 0.0) / (2.5 * px)) * (1.0 - under) * 0.25;
    vec3 lipC = mix(rgb(240, 250, 255), rgb(140, 160, 255), dk);
    col = mix(col, lipC, clamp(lip, 0.0, 1.0) * smoothstep(-0.05, 0.12, u));

    // Vignettage léger + tramage anti-bandes
    vec2 q = uv - 0.5;
    col *= 1.0 - dot(q, q) * mix(0.08, 0.25, dk);
    col += (hash(uv * 4096.0) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
