pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Métriques et couleurs du Control Center Tahoe (mesurées sur les captures
// Apple du Control Center de macOS 26, ramenées en points).
//
// Sur Tahoe, les modules du Control Center et le HUD volume/luminosité gardent
// un contenu BLANC en mode clair comme en mode sombre (verre "clair" posé sur le
// fond d'écran) : seule la teinte du verre change.
Singleton {
    // ---- Grille (4 colonnes) ----
    readonly property int cell: 61             // module 1x1 (cercle)
    readonly property int gap: 11              // espace entre modules
    readonly property int cols: 4
    readonly property int width: cols * cell + (cols - 1) * gap   // 277
    function span(n) { return n * cell + (n - 1) * gap; }
    readonly property int marginRight: 10      // bord droit de l'écran -> modules
    readonly property int marginTop: 6         // bas de la barre des menus -> modules

    // ---- Rayons ----
    readonly property int radiusTile: 16       // modules rectangulaires (Écran, Son)
    readonly property int radiusLarge: 21      // module 2x2 (Lecture en cours)
    readonly property int radiusCard: 24       // module déplié (Wi-Fi, Bluetooth, ...)
    readonly property int radiusRow: 8         // survol d'une ligne de liste

    // ---- Typographie ----
    readonly property int titleSize: 12        // "Wi-Fi", "Écran", "Son" (semibold)
    readonly property int subtitleSize: 11     // "Maison", "Activé"
    readonly property int headerSize: 13       // en-tête d'un module déplié
    readonly property int rowSize: 13          // lignes de liste
    readonly property int captionSize: 11      // "Réseaux connus"
    // Approche des titres : Inter 12 a la même chasse que SF Pro 12,4 (mesuré sur
    // "Display" dans les captures Apple) : pas de resserrement.
    readonly property real tracking: 0

    // ---- Couleurs (contenu blanc dans les deux modes) ----
    readonly property color text: "#FFFFFF"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.68)
    readonly property color textTertiary: Qt.rgba(1, 1, 1, 0.42)
    readonly property real disabledOpacity: 0.42

    // Verre des modules : plus clair en mode clair, plus sombre en mode sombre.
    // Alpha >= 0.26 pour rester au-dessus du seuil ignore_alpha (0.25) de Hyprland (flou).
    readonly property color tile: Theme.glassModule
    readonly property color tileHover: Theme.glassModuleHover
    readonly property color card: Theme.dark ? Qt.rgba(0.13, 0.13, 0.14, 0.58) : Qt.rgba(0.36, 0.36, 0.38, 0.52)

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
