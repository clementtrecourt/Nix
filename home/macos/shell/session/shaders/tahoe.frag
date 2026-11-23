#version 440
// Fond d'écran procédural inspiré du fond par défaut de macOS Tahoe 26 :
// vagues de verre bleu superposées (clair) / bleu nuit-violet (sombre).
// Compilé en .qsb par session/shaders/build.sh (qsb de qtshadertools).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;   // largeur / hauteur
    float dark;     // 0 = clair, 1 = sombre (interpolé pour le fondu)
};

const int N = 6;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Bord supérieur de la bande i (y vers le bas, x dans [0,1])
float edge(int i, float x) {
    float fi = float(i);
    // La vague monte de bas-gauche vers haut-droite, crête vers x ~ 0.7
    float y0 = 0.40 + 0.105 * fi;
    float c = 0.72 - 0.09 * fi;
    float a = 0.17 - 0.012 * fi;
    float w = 0.20 + 0.035 * fi;
    float t = (x - c) / w;
    return y0 - a * exp(-t * t) - 0.17 * (x - 0.5) + 0.022 * sin(x * 4.2 + fi * 1.9);
}

vec3 bandColor(int i, float d, float x, float dk) {
    float fi = float(i) / float(N - 1);
    vec3 lBack = vec3(0.62, 0.80, 0.97);
    vec3 lFront = vec3(0.05, 0.25, 0.72);
    vec3 dBack = vec3(0.30, 0.30, 0.78);
    vec3 dFront = vec3(0.07, 0.11, 0.42);
    vec3 top = mix(mix(lBack, lFront, fi), mix(dBack, dFront, fi), dk);
    vec3 deepL = mix(vec3(0.20, 0.47, 0.90), vec3(0.03, 0.14, 0.50), fi);
    vec3 deepD = mix(vec3(0.13, 0.14, 0.46), vec3(0.03, 0.05, 0.20), fi);
    vec3 deep = mix(deepL, deepD, dk);
    vec3 c = mix(top, deep, smoothstep(0.0, 0.22, d));
    c += mix(vec3(0.10, 0.10, 0.12), vec3(0.06, 0.04, 0.12), dk) * (1.0 - x);
    return c;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float x = uv.x;
    float y = uv.y;
    float px = 1.0 / 1000.0;

    vec3 skyL = mix(vec3(0.86, 0.92, 0.98), vec3(0.62, 0.79, 0.96), smoothstep(0.0, 0.8, y));
    vec3 skyD = mix(vec3(0.02, 0.03, 0.09), vec3(0.08, 0.08, 0.24), smoothstep(0.0, 0.8, y));
    vec3 col = mix(skyL, skyD, dark);
    // lueur diffuse derrière la crête de la vague
    vec2 g = vec2((x - 0.74) * aspect, y - 0.30);
    col += mix(vec3(0.06, 0.08, 0.10), vec3(0.10, 0.10, 0.30), dark) * exp(-dot(g, g) / 0.10);

    for (int i = 0; i < N; ++i) {
        float b = edge(i, x);
        float db = (edge(i, x + 0.001) - b) / 0.001;
        float d = (y - b) / sqrt(1.0 + db * db / (aspect * aspect));
        // ombre portée, teintée (bleutée en clair) sur ce qui est derrière
        float sh = exp(-max(-d, 0.0) / 0.04) * (1.0 - smoothstep(-px, px, d));
        vec3 shC = mix(vec3(0.55, 0.70, 0.95), vec3(0.25, 0.20, 0.45), dark);
        col = mix(col, col * shC, sh * mix(0.55, 0.75, dark));
        float cov = smoothstep(-px, px, d);
        vec3 bc = bandColor(i, max(d, 0.0), x, dark);
        vec3 rimC = mix(vec3(1.0), vec3(0.70, 0.74, 1.0), dark);
        float dd = max(d, 0.0);
        // arête vive + reflet interne (double liseré du verre épais) + halo
        float rim = exp(-dd / 0.0022) * mix(0.90, 0.75, dark)
                  + exp(-abs(dd - 0.012) / 0.004) * mix(0.22, 0.14, dark)
                  + exp(-dd / 0.045) * mix(0.28, 0.18, dark);
        bc = mix(bc, rimC, clamp(rim, 0.0, 1.0));
        // verre translucide près de l'arête : on devine les couches derrière
        float alpha = mix(0.62, 0.96, smoothstep(0.0, 0.16, dd));
        col = mix(col, bc, cov * alpha);
    }

    vec2 q = uv - 0.5;
    col *= 1.0 - dot(q, q) * mix(0.10, 0.35, dark);
    col += (hash(uv * 4096.0) - 0.5) / 255.0;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
