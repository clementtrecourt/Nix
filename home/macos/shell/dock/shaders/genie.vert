#version 440
// Effet génie de macOS (minimiser dans le Dock), sur un maillage en grille.
// Chaque ligne du maillage glisse vers le Dock avec un retard d'autant plus grand
// qu'elle est haute (la fenêtre s'étire en « coulant »), et sa largeur suit un
// entonnoir qui se resserre de la largeur de la fenêtre vers celle de l'icône.
// progress : 0 = fenêtre en place, 1 = miniature dans le Dock.
// mode     : 0 = génie, 1 = échelle (réduction simple).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float mode;
    vec4 src;   // x, y, largeur, hauteur de la fenêtre (px, repère de l'effet)
    vec4 dst;   // rectangle de la miniature dans le Dock
    float radius;
};

float ease(float t) { return t * t * (3.0 - 2.0 * t); }

void main() {
    vec2 uv = qt_MultiTexCoord0;
    qt_TexCoord0 = uv;
    float p = clamp(progress, 0.0, 1.0);
    vec2 pos;

    if (mode > 0.5) {
        // Échelle : interpolation directe des rectangles
        float e = ease(p);
        vec4 r = mix(src, dst, e);
        pos = r.xy + uv * r.zw;
    } else {
        // 1) Glissement vertical, en retard pour les lignes hautes
        float k = 0.45;
        float sRow = clamp((p - (1.0 - uv.y) * k) / (1.0 - k), 0.0, 1.0);
        // Aspiration : départ lent, arrivée rapide
        float slide = mix(ease(sRow), sRow * sRow, 0.35);
        float ys = src.y + uv.y * src.w;
        float yt = dst.y + uv.y * dst.w;
        float y = mix(ys, yt, slide);

        // 2) Entonnoir : la largeur dépend de la hauteur courante de la ligne
        float squeeze = smoothstep(0.0, 0.42, p);
        // Courbe en S : flancs verticaux sous la fenêtre, resserrement près du Dock
        float c = smoothstep(src.y, dst.y, y);
        c = c * c * (3.0 - 2.0 * c);
        float xl = mix(src.x, dst.x, c);
        float xr = mix(src.x + src.z, dst.x + dst.z, c);
        float x = mix(src.x + uv.x * src.z, mix(xl, xr, uv.x), squeeze);
        pos = vec2(x, y);
    }
    gl_Position = qt_Matrix * vec4(pos, 0.0, 1.0);
}
