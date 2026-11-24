pragma Singleton

import QtQuick
import Quickshell

// Jetons visuels macOS Tahoe (macOS 26, "Liquid Glass").
// Tous les composants lisent leurs couleurs / rayons / durées ici.
Singleton {
    id: root

    // Apparence : piloté par services/Appearance (Control Center > Dark Mode).
    property bool dark: true

    // ---- Typographie (SF Pro n'est pas redistribuable : Inter, très proche) ----
    readonly property string font: "Inter"
    readonly property string fontDisplay: "Inter Display"
    readonly property string fontMono: "JetBrains Mono"
    readonly property int fontSize: 13          // corps macOS (13pt)
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeMenuBar: 13

    // ---- Couleurs système (NSColor) ----
    readonly property color accent: dark ? "#0A84FF" : "#007AFF"
    readonly property color red: dark ? "#FF453A" : "#FF3B30"
    readonly property color orange: dark ? "#FF9F0A" : "#FF9500"
    readonly property color yellow: dark ? "#FFD60A" : "#FFCC00"
    readonly property color green: dark ? "#32D74B" : "#28CD41"
    readonly property color purple: dark ? "#BF5AF2" : "#AF52DE"
    readonly property color pink: dark ? "#FF375F" : "#FF2D55"

    readonly property color label: dark ? "#FFFFFF" : "#000000"
    readonly property color labelSecondary: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.50)
    readonly property color labelTertiary: dark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.26)
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color fillHover: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.09)

    // ---- Matériau "Liquid Glass" ----
    // Le flou d'arrière-plan est fait par Hyprland (layerrule blur sur les namespaces
    // "macos-*") : ces teintes se posent par-dessus.
    readonly property color glass: dark ? Qt.rgba(0.12, 0.12, 0.13, 0.42) : Qt.rgba(0.98, 0.98, 0.99, 0.48)
    readonly property color glassThick: dark ? Qt.rgba(0.11, 0.11, 0.12, 0.70) : Qt.rgba(0.97, 0.97, 0.98, 0.78)
    readonly property color glassHighlight: dark ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.95)
    readonly property color glassStroke: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.45 : 0.22)

    // Menus déroulants / contextuels
    readonly property color menuBackground: dark ? Qt.rgba(0.16, 0.16, 0.17, 0.62) : Qt.rgba(0.96, 0.96, 0.97, 0.66)
    readonly property color menuHighlight: accent
    readonly property color menuHighlightText: "#FFFFFF"

    // ---- Géométrie ----
    // Tahoe sans encoche : 30 pt, sans fond (512pixels, macOS 26.0 sur MacBook
    // Air M1 : pastille du titre ouvert de y=3 à 26,5 pt, menu à y=31 pt)
    readonly property int menuBarHeight: 30
    readonly property int radiusMenu: 12
    readonly property int radiusMenuItem: 7
    readonly property int radiusPanel: 26         // Control Center, Notification Center
    readonly property int radiusTile: 18          // modules du Control Center
    readonly property int radiusDock: 28
    readonly property int radiusWindow: 16
    readonly property int radiusSmall: 8

    // ---- Animations (ressorts macOS approximés) ----
    readonly property int durFast: 120
    readonly property int durMed: 240
    readonly property int durSlow: 420
    // Courbe "ease-out" douce façon AppKit, à utiliser via Easing.BezierSpline
    readonly property var curveStandard: [0.25, 0.1, 0.25, 1.0, 1, 1]
    readonly property var curveSpring: [0.18, 0.89, 0.32, 1.12, 1, 1]  // léger dépassement
    readonly property var curveEmphasized: [0.2, 0.9, 0.1, 1.0, 1, 1]

    // ---- Liquid Glass : réglages fins (Glass.qml, agent controlcenter) ----
    // Lueur interne près des bords (épaisseur du verre)
    readonly property color glassGlow: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.40)
    // Modules du Control Center / HUD : verre "clair" plus transparent que les panneaux.
    // Mode clair : voile BLANC léger (le module est une version plus claire du fond,
    // jamais grisée) ; mode sombre : voile gris foncé.
    readonly property color glassModule: dark ? Qt.rgba(0.22, 0.22, 0.23, 0.36) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color glassModuleHover: dark ? Qt.rgba(0.30, 0.30, 0.31, 0.40) : Qt.rgba(1, 1, 1, 0.20)

    // Seuil ignore_alpha de la layerrule Hyprland des surfaces "macos-*" : tout
    // pixel plus opaque reçoit le flou d'arrière-plan. Les ombres dessinées dans
    // une surface doivent rester sous ce seuil (sinon halo flouté).
    readonly property real layerBlurIgnoreAlpha: 0.05

    // Bande sombre interne du Liquid Glass (Glass.qml : réfraction près des bords)
    readonly property color glassShade: dark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(0.2, 0.18, 0.16, 0.05)

    // ---- Boutons de fenêtre (feux tricolores) Tahoe 26 ----
    // Relevés à 2x sur les captures Tahoe 26 de 512pixels (Force Quit, System
    // Settings ▸ Wallpaper) : disque de 14 pt plein + anneau d'un demi-point
    // plus sombre. Couleurs identiques en clair et en sombre.
    readonly property color trafficRed: "#EC6765"
    readonly property color trafficRedRing: "#E73935"
    readonly property color trafficYellow: "#F2CA44"
    readonly property color trafficYellowRing: "#EEBA0B"
    readonly property color trafficGreen: "#65C466"
    readonly property color trafficGreenRing: "#35B338"
    // Bouton désactivé / fenêtre inactive : voile translucide qui prend la
    // teinte du fond (220 + anneau 210 sur blanc ; bleu-gris #BCD3DA sur le
    // verre teinté d'About This Mac)
    readonly property color trafficInactive: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.137)
    readonly property color trafficInactiveRing: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.176)
    readonly property real trafficRingWidth: 0.5

    // ---- Barre des menus : surbrillance des éléments de menu ----
    // Tahoe ne prend pas l'accent brut (#007AFF) : bleu plus clair, « vitré »
    // (#4E8AF0..#5691F4 sur le menu Finder de 512pixels, macOS 26.0)
    readonly property color menuSelection: dark ? "#3A82F2" : "#4E8AF0"
}
