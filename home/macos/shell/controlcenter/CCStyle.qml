pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Métriques et couleurs du Control Center Tahoe, mesurées sur une vraie
// capture de macOS 26.0 (TidBITS, MacBook Air 2560x1600 en 1440x900 points,
// soit 1,78 px/pt) et ramenées en points.
//
// Sur Tahoe, les modules du Control Center et le HUD volume/luminosité gardent
// un contenu BLANC en mode clair comme en mode sombre (verre "clair" posé sur le
// fond d'écran) : seule la teinte du verre change.
Singleton {
    // ---- Grille (4 colonnes) ----
    readonly property int cell: 63             // module 1x1 (cercle) : 113 px / 1,78
    readonly property int gap: 13              // espace entre modules : 23 px / 1,78
    readonly property int cols: 4
    readonly property int width: cols * cell + (cols - 1) * gap   // 291
    function span(n) { return n * cell + (n - 1) * gap; }
    readonly property int marginRight: 14      // bord droit de l'écran -> modules
    readonly property int marginTop: 6         // bas de la barre des menus -> modules

    // ---- Rayons ----
    // Tahoe arrondit fort : ~0,35 x la hauteur pour les modules 4x1 (40 px pour
    // 113 px), ~0,18 x le côté pour le 2x2.
    readonly property int radiusTile: 22       // modules rectangulaires (Écran, Son)
    readonly property int radiusLarge: 25      // module 2x2 (Lecture en cours)
    readonly property int radiusCard: 26       // module déplié (Wi-Fi, Bluetooth, ...)
    readonly property int radiusHud: 22        // HUD volume / luminosité (même dessin que "Son")
    readonly property int radiusRow: 8         // survol d'une ligne de liste

    // ---- Typographie ----
    readonly property int titleSize: 12        // "Wi-Fi", "Bluetooth", "Pas de lecture" (semibold)
    readonly property int sliderTitleSize: 13  // "Écran", "Son", titre du HUD (cap 9,3 pt mesurée)
    readonly property int subtitleSize: 11     // "Maison", "Activé"
    readonly property int headerSize: 13       // en-tête d'un module déplié
    readonly property int rowSize: 13          // lignes de liste
    readonly property int captionSize: 11      // "Réseaux connus"
    // Approche des titres : Inter a quasiment la chasse de SF Pro à corps égal :
    // pas de resserrement.
    readonly property real tracking: 0
    // Tous les textes du composant : renderType CurveRendering (antialiasing en
    // niveaux de gris comme macOS ; le rendu par défaut fait ici de l'antialiasing
    // sous-pixel, franges colorées sur le verre).

    // ---- Couleurs (contenu blanc dans les deux modes) ----
    readonly property color text: "#FFFFFF"
    // Texte secondaire en "vibrancy" : blanc translucide, qui prend donc la teinte
    // du fond flouté (bleuté sur un fond bleu, comme « TidBITS Mesh » sur Tahoe).
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.66)
    readonly property color textTertiary: Qt.rgba(1, 1, 1, 0.42)
    readonly property real disabledOpacity: 0.42

    // Contrôles "vibrancy" (commandes de lecture, « Modifier les commandes ») :
    // blanc translucide, éteint plus transparent.
    readonly property color vibrant: Qt.rgba(1, 1, 1, 0.80)
    readonly property color vibrantDim: Qt.rgba(1, 1, 1, 0.42)

    // Verre des modules : en mode clair, version plus CLAIRE du fond (voile blanc
    // léger) ; en mode sombre, voile gris foncé. Toujours au-dessus du seuil
    // ignore_alpha de Hyprland (Theme.layerBlurIgnoreAlpha = 0.05), sinon pas de flou.
    readonly property color tile: Theme.glassModule
    readonly property color tileHover: Theme.glassModuleHover
    // Module déplié : un peu plus dense que les modules pour la lisibilité des listes
    readonly property color card: Theme.dark ? Qt.rgba(0.13, 0.13, 0.14, 0.58) : Qt.rgba(1, 1, 1, 0.16)

    // Cercle d'icône éteint / allumé (dans les pilules)
    readonly property color circleOff: Qt.rgba(1, 1, 1, 0.20)
    readonly property color circleOffHover: Qt.rgba(1, 1, 1, 0.28)
    readonly property color circleOn: "#FFFFFF"
    readonly property color blue: "#0A84FF"     // Wi-Fi, Bluetooth, AirDrop allumés
    readonly property color indigo: "#5E5CE6"   // Concentration
    readonly property color glyphOnDark: "#1C1C1E"

    // Curseurs
    readonly property int trackHeight: 4
    readonly property color trackFill: "#FFFFFF"
    readonly property color trackEmpty: Qt.rgba(1, 1, 1, 0.16)
    readonly property color tick: Qt.rgba(1, 1, 1, 0.40)

    // Lignes de liste
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color separator: Qt.rgba(1, 1, 1, 0.14)

    // ---- Mouvements (ressorts Tahoe approchés) ----
    readonly property int durOpen: 360
    readonly property int durClose: 200
    readonly property int durExpand: 440
    readonly property int durCollapse: 320
}
