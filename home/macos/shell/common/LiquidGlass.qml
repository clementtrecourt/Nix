import QtQuick
import Quickshell
import qs.common

// Matériau Liquid Glass de macOS Tahoe 26 AVEC réfraction du fond.
//
// Remplaçant de Glass.qml (même API : radius, tint, thick, shadowEnabled,
// shadowBlur, shadowOffset, shadowColor, réglages fins du liseré, contenu par
// défaut) avec en plus :
//
//   backdrop : "wallpaper" | "snapshot" | "none"
//     - "wallpaper" : le fond d'écran (session/WallpaperView) est rendu dans la
//       fenêtre, décalé à la position du verre, et sert de texture : réfraction
//       en direct, sans capture. Valable là où il n'y a QUE le fond d'écran
//       derrière le verre (Dock, barre de menus : zones exclusives).
//     - "snapshot" : `backdropItem` est un LiquidGlassSnapshot (capture unique
//       de l'écran prise AVANT l'apparition du panneau). Panneaux temporaires.
//     - "none" : repli identique à Glass.qml (teinte seule ; le flou vient de
//       la layerrule Hyprland du namespace "macos-*").
//   variant : "regular" | "clear" (Apple HIG : le « clear » est plus
//     transparent, moins flouté, sans adaptation ; il assombrit le fond clair).
//   backdropItem : fournisseur de fond partagé, à la taille de l'écran et à
//     l'origine de l'écran (LiquidGlassWallpaper ou LiquidGlassSnapshot). Si
//     backdrop = "wallpaper" et rien n'est fourni, un LiquidGlassWallpaper
//     interne est créé (une copie décodée du fond par verre : partager un
//     fournisseur quand une fenêtre contient plusieurs verres).
//   windowOrigin : position de la fenêtre sur l'écran. Calculée depuis les
//     ancres/marges de la PanelWindow ; à fournir si la fenêtre est décalée par
//     la zone exclusive d'une autre surface.
//
// IMPORTANT (Hyprland) : quand le verre réfracte lui-même son fond, la surface
// ne doit PAS être floutée par Hyprland (le flou du compositeur se verrait au
// travers de l'ombre et doublerait le flou) : utiliser un namespace
// "macos-lg-*" et la règle `layerrule = blur off, match:namespace ^(macos-lg-.*)$`
// placée APRÈS la règle générale "macos-*".
//
// Pipeline : ShaderEffectSource (région du fond autour du verre, à demi-
// résolution) -> flou gaussien horizontal -> vertical (deux ShaderEffect mis en
// cache, recalculés seulement si le fond ou la géométrie change) -> un seul
// shader de verre par image (liquidglass.frag : lentille SDF, dispersion,
// teinte adaptative, liseré, ombre).
Item {
    id: root

    // ---- API commune avec Glass.qml ----
    property real radius: Theme.radiusPanel
    property bool thick: false
    property color tint: _defaultTint
    property bool shadowEnabled: true
    property real shadowBlur: 1.0          // 1.0 = sigma 14 px
    property int shadowOffset: 8
    property color shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.32 : 0.16)
    default property alias content: contentItem.data

    // Valeurs relevées sur les captures Tahoe (Dock clair : liseré d'un demi-
    // point ~ +30 niveaux, lueur interne ~ +6 niveaux sur ~7 pt).
    property color rimColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.55)
    property real rimWidth: 1.0
    property real rimBase: 0.35
    property color glowColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.16)
    property real glowWidth: Math.min(10, Math.min(width, height) * 0.2)
    property color shadeColor: Theme.dark ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(0, 0, 0, 0.04)
    property real shadeWidth: Math.min(7, Math.min(width, height) * 0.14)
    property real lightAngle: 225
    // Sans réfraction, l'ombre reste sous le seuil ignore_alpha de Hyprland
    // (cf. Glass.qml) ; avec réfraction (namespace sans flou), libre.
    property real shadowMax: refracting ? 1.0 : Theme.layerBlurIgnoreAlpha - 0.003

    // ---- Liquid Glass ----
    property string backdrop: "none"
    property string variant: "regular"
    property Item backdropItem: null
    property point windowOrigin: _autoWindowOrigin

    readonly property bool clear: variant === "clear"
    // Bande de lentille : ~18 px sur un panneau, au plus ~1/4 du petit côté
    property real bezel: Math.max(3, Math.min(18, Math.min(width, height) * 0.22))
    // Déplacement au bord : le pixel du bord lit le fond 1,5 bande plus loin
    // vers l'intérieur (fond comprimé et inversé dans la bande, signature du
    // Liquid Glass) ; nul au-delà de la bande
    property real refraction: bezel * (clear ? 1.3 : 1.5)
    property real dispersion: 0.0          // Apple : nulle ou quasi nulle
    // Flou (sigma, px logiques) : Tahoe floute nettement moins que Big Sur ;
    // les grands verres diffusent un peu plus (WWDC25 « Meet Liquid Glass »)
    property real blur: clear ? 1.5 : Math.max(3, Math.min(8, Math.min(width, height) * 0.11))
    property real saturation: clear ? 1.3 : (Theme.dark ? 1.25 : 1.7)
    property real adaptive: clear ? 0.0 : 0.7
    // Voile sombre sous le contenu : Apple (HIG Materials) recommande ~0.35
    // pour la variante « clear » posée sur un fond clair
    property real dim: 0.0

    readonly property var _src: backdrop === "wallpaper" ? (backdropItem ?? internalWallpaper.item)
                                : backdrop === "snapshot" ? backdropItem : null
    // Le fond est prêt (le snapshot n'a pas toujours de contenu)
    readonly property bool refracting: _src !== null && _src !== undefined
                                       && (_src.ready === undefined || _src.ready)
                                       && width > 0 && height > 0

    // Teinte = cible de LUMINANCE du fond flouté (la chrominance du fond est
    // gardée, x saturation) : relevé sur le Dock clair et les modules du
    // Control Center de Tahoe, L' ~ 0,59 L + 68/255 (45 -> 95, 90 -> 121,
    // 150 -> 157), soit une cible 0,66 à 41 %. Une teinte colorée ajoute sa
    // propre chrominance au prorata de son alpha.
    readonly property color _defaultTint: clear
        ? (Theme.dark ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.08))
        : thick ? (Theme.dark ? Qt.rgba(0.11, 0.11, 0.12, 0.72) : Qt.rgba(0.94, 0.94, 0.95, 0.72))
        : (Theme.dark ? Qt.rgba(0.10, 0.10, 0.11, 0.46) : Qt.rgba(0.66, 0.66, 0.67, 0.41))

    // ---- Position du verre sur l'écran ----
    readonly property var _win: QsWindow.window
    readonly property point _autoWindowOrigin: {
        const w = _win;
        if (!w || !w.screen) return Qt.point(0, 0);
        const s = w.screen, a = w.anchors, m = w.margins;
        if (!a) return Qt.point(0, 0);
        const ml = m?.left ?? 0, mr = m?.right ?? 0, mt = m?.top ?? 0, mb = m?.bottom ?? 0;
        const x = a.left ? ml : a.right ? s.width - w.width - mr : (s.width - w.width) / 2;
        const y = a.top ? mt : a.bottom ? s.height - w.height - mb : (s.height - w.height) / 2;
        return Qt.point(x, y);
    }
    // Position dans la fenêtre : la liaison lit x/y/parent de tous les ancêtres,
    // elle est donc réévaluée dès que l'un d'eux bouge (transformations ignorées).
    readonly property point _scenePos: {
        let x = 0, y = 0;
        for (let it = root; it; it = it.parent) { x += it.x; y += it.y; }
        return Qt.point(x, y);
    }
    readonly property real screenX: windowOrigin.x + _scenePos.x
    readonly property real screenY: windowOrigin.y + _scenePos.y

    readonly property real _sigma: shadowEnabled ? Math.max(0.5, shadowBlur * 14) : 0
    readonly property int _pad: shadowEnabled ? Math.ceil(_sigma * 3 + Math.abs(shadowOffset)) : 1
    // Marge de fond autour du verre (noyau du flou) et sous-échantillonnage
    readonly property int _margin: Math.ceil(blur * 3) + 2
    readonly property real _ds: blur >= 3 ? 2 : 1
    readonly property real _dpr: _win?.devicePixelRatio ?? 1

    // Fond d'écran interne (si aucun fournisseur partagé n'est donné)
    Loader {
        id: internalWallpaper
        active: root.backdrop === "wallpaper" && !root.backdropItem
        sourceComponent: LiquidGlassWallpaper {
            screen: root._win?.screen ?? null
        }
    }

    // ---- Chaîne de flou (mise en cache) ----
    readonly property size _texSize: Qt.size(Math.max(1, Math.ceil((width + 2 * _margin) * _dpr / _ds)),
                                             Math.max(1, Math.ceil((height + 2 * _margin) * _dpr / _ds)))
    ShaderEffectSource {
        id: region
        visible: false
        width: root.width + 2 * root._margin
        height: root.height + 2 * root._margin
        // Les fournisseurs de fond sont invisibles : rendus seulement ici
        sourceItem: root.refracting ? root._src : null
        live: true
        smooth: true
        sourceRect: Qt.rect(root.screenX - root._margin, root.screenY - root._margin,
                            root.width + 2 * root._margin, root.height + 2 * root._margin)
        textureSize: root._texSize
    }
    ShaderEffect {
        id: blurH
        width: root._texSize.width
        height: root._texSize.height
        visible: false   // rendu seulement dans blurHTex (un item invisible y est rendu quand même)
        property var source: region
        property vector2d texelStep: Qt.vector2d(1 / width, 0)
        property real sigma: root.blur * root._dpr / root._ds
        fragmentShader: Qt.resolvedUrl("../assets/shaders/liquidglass_blur.frag.qsb")
    }
    ShaderEffectSource {
        id: blurHTex
        visible: false
        sourceItem: root.refracting ? blurH : null
        live: true
        smooth: true
        textureSize: root._texSize
    }
    ShaderEffect {
        id: blurV
        width: root._texSize.width
        height: root._texSize.height
        visible: false   // rendu seulement dans blurred
        property var source: blurHTex
        property vector2d texelStep: Qt.vector2d(0, 1 / height)
        property real sigma: root.blur * root._dpr / root._ds
        fragmentShader: Qt.resolvedUrl("../assets/shaders/liquidglass_blur.frag.qsb")
    }
    ShaderEffectSource {
        id: blurred
        visible: false
        sourceItem: root.refracting ? blurV : dummy
        live: true
        smooth: true
        textureSize: root.refracting ? root._texSize : Qt.size(1, 1)
    }
    // Texture factice (le shader exige toujours une texture liée)
    Item { id: dummy; width: 1; height: 1; visible: false }

    // ---- Verre ----
    ShaderEffect {
        id: fx
        x: -root._pad
        y: -root._pad
        width: root.width + 2 * root._pad
        height: root.height + 2 * root._pad
        visible: root.width > 0 && root.height > 0
        fragmentShader: Qt.resolvedUrl("../assets/shaders/liquidglass.frag.qsb")

        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d plate: Qt.vector4d(root._pad, root._pad, root.width, root.height)
        property real radius: root.radius
        property color tint: root.tint
        property var bg: blurred
        property vector4d bgRect: Qt.vector4d(root._pad - root._margin, root._pad - root._margin,
                                              root.width + 2 * root._margin, root.height + 2 * root._margin)
        property real hasBg: root.refracting ? 1 : 0
        property real bezel: root.bezel
        property real refraction: root.refraction
        property real dispersion: root.dispersion
        property real saturation: root.saturation
        property real adaptive: root.adaptive
        property real darkMode: Theme.dark ? 1 : 0
        property real dim: root.dim
        property color rimColor: root.rimColor
        property real rimWidth: root.rimWidth
        property real rimBase: root.rimBase
        property color glowColor: root.glowColor
        property real glowWidth: root.glowWidth
        property color shadeColor: root.shadeColor
        property real shadeWidth: root.shadeWidth
        property color shadowColor: root.shadowColor
        property real shadowSigma: root._sigma
        property real shadowOffsetY: root.shadowOffset
        property real shadowMax: root.shadowMax
        property vector2d lightDir: Qt.vector2d(-Math.cos(root.lightAngle * Math.PI / 180),
                                                -Math.sin(root.lightAngle * Math.PI / 180))
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
