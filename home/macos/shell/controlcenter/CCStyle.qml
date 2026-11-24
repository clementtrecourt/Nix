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
    // Ajustement d'un cercle sur le coin des modules de la capture Apple :
    // 40 px (21 pt) pour Display / Sound, 55 px (28,5 pt) pour Now Playing.
    readonly property int radiusTile: 21       // modules rectangulaires (Display, Sound)
    readonly property int radiusLarge: 28      // module 2x2 (Now Playing)
    readonly property int radiusCard: 28       // module déplié (Wi-Fi, Bluetooth, ...)
    readonly property int radiusHud: 21        // HUD volume / luminosité (même dessin que "Sound")
    readonly property int radiusRow: 8         // survol d'une ligne de liste

    // ---- Typographie ----
    // Mesuré sur la capture Apple (support.apple.com, Tahoe 26, 1,92 px/pt) :
    // hauteur de capitale 9,4 pt pour « Wi-Fi », « Display », « Not Playing »
    // (13 pt), 7,8 pt pour « Home » (11 pt). Idem sur le HUD.
    readonly property int titleSize: 13        // "Wi-Fi", "Bluetooth", "Not Playing" (semibold)
    readonly property int sliderTitleSize: 13  // "Display", "Sound", titre du HUD
    readonly property int subtitleSize: 11     // "Home", "On"
    readonly property int headerSize: 13       // en-tête d'un module déplié
    readonly property int rowSize: 13          // lignes de liste
    readonly property int captionSize: 11      // "Réseaux connus"
    // Approche des titres : Inter a quasiment la chasse de SF Pro à corps égal :
    // pas de resserrement.
    readonly property real tracking: 0
    // Tous les textes du composant : renderType NativeRendering (antialiasing en
    // niveaux de gris comme macOS ; le rendu par défaut fait ici de l'antialiasing
    // sous-pixel, franges colorées sur le verre).

    // ---- Couleurs (contenu blanc dans les deux modes) ----
    readonly property color text: "#FFFFFF"
    // Texte secondaire en "vibrancy" : blanc translucide, qui prend donc la teinte
    // du fond flouté (bleuté sur un fond bleu, comme « TidBITS Mesh » sur Tahoe).
    // (capture Apple : « Home » sous « Wi-Fi » est presque aussi blanc que le titre)
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.80)
    readonly property color textTertiary: Qt.rgba(1, 1, 1, 0.42)
    readonly property real disabledOpacity: 0.42

    // Contrôles "vibrancy" (commandes de lecture, « Modifier les commandes ») :
    // blanc translucide, éteint plus transparent.
    readonly property color vibrant: Qt.rgba(1, 1, 1, 0.85)
    readonly property color vibrantDim: Qt.rgba(1, 1, 1, 0.40)

    // Verre des modules (réfraction de la capture d'écran, LiquidGlass).
    // La teinte est une cible de LUMINANCE (cf. liquidglass.frag :
    // L' = mix(L, lum(teinte), alpha), chrominance x saturation x (1 - alpha/2)).
    //  - clair : relevé sur les vraies captures de Tahoe 26 (support.apple.com
    //    « Use Control Center » /26/, MacStories), fond -> intérieur du module :
    //    0,60 -> 0,50 (vert d'eau 120,162,158 -> 61,143,159), 0,34 -> 0,36 (bleu
    //    32,94,175 -> 0,104,236), 0,74 -> 0,57 (gris 183,191,206 -> 138,145,162).
    //    Soit L' = 0,54 L + 0,18 : le verre ASSOMBRIT un fond clair (~-25 %) et
    //    garde un fond sombre, pour que le contenu blanc reste lisible ; la
    //    chrominance est renforcée (x1,6 sur le bleu d'Apple, ~x1 sur le gris
    //    bleuté de MacStories) : compromis x1,4.
    //    => teinte grise de luminance 0,38 à 46 %, saturation 1,8.
    //  - sombre : verre fumé (fond nettement assombri, couleur gardée).
    readonly property color tile: Theme.dark ? Qt.rgba(0.07, 0.07, 0.08, 0.46) : Qt.rgba(0.38, 0.38, 0.38, 0.46)
    readonly property color tileHover: Theme.dark ? Qt.rgba(0.20, 0.20, 0.21, 0.42) : Qt.rgba(0.47, 0.47, 0.47, 0.46)
    // Module déplié : même matériau, un peu plus dense pour la lisibilité des
    // listes (pas de référence Tahoe d'un module déplié : non vérifié)
    readonly property color card: Theme.dark ? Qt.rgba(0.08, 0.08, 0.09, 0.56) : Qt.rgba(0.33, 0.33, 0.33, 0.56)
    // Réglages du verre des modules (LiquidGlass) : flou léger (fond « presque
    // net » sur Tahoe), chrominance renforcée, teinte adaptative modérée.
    readonly property real glassBlur: 2.5
    readonly property real glassSaturation: Theme.dark ? 1.5 : 1.8
    readonly property real glassAdaptive: Theme.dark ? 0.45 : 0.30
    readonly property real cardBlur: 9
    // HUD volume / luminosité : verre nettement plus sombre et plus saturé que
    // les modules (capture Tahoe, fond bleu 93/160/210 -> 22/125/188 dans le
    // HUD : luminance 0,58 -> 0,42, chrominance x 1,45), pour le contenu blanc.
    readonly property color hudTint: Theme.dark ? Qt.rgba(0, 0, 0, 0.40) : Qt.rgba(0, 0, 0, 0.27)
    readonly property real hudSaturation: Theme.dark ? 1.40 : 1.50
    // Liseré des modules : fin, vif sur l'arc haut-gauche et l'arc bas-droit,
    // discret mais présent sur les flancs (captures Apple / MacStories).
    readonly property real rimBase: 0.20
    // Bande d'épaisseur sous le liseré : quasi absente sur Tahoe (le module ne
    // doit pas être cerné de sombre)
    readonly property real edgeDarken: 0.08
    // Pas d'ombre portée : sur Tahoe le fond décroît de façon monotone jusqu'au
    // liseré (aucun anneau sombre autour des modules).
    readonly property bool tileShadow: false

    // Cercle d'icône éteint / allumé (dans les pilules)
    readonly property color circleOff: Qt.rgba(1, 1, 1, 0.20)
    readonly property color circleOffHover: Qt.rgba(1, 1, 1, 0.28)
    readonly property color circleOn: "#FFFFFF"
    readonly property color blue: "#007AFF"     // Wi-Fi, Bluetooth, AirDrop allumés (capture : #007BFF)
    readonly property color indigo: "#5E5CE6"   // Concentration
    readonly property color glyphOnDark: "#1C1C1E"

    // Curseurs
    readonly property int trackHeight: 4
    readonly property color trackFill: "#FFFFFF"
    // Piste vide PLUS SOMBRE que le module (Tahoe : 0,104,239 -> 0,94,214, x0,9 ;
    // MacStories 148 -> 140) : voile noir
    readonly property color trackEmpty: Theme.dark ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color tick: Qt.rgba(1, 1, 1, 0.40)
    // HUD : piste vide PLUS CLAIRE que le verre (capture Tahoe du HUD volume :
    // 126 -> 140, blanc ~10 %), crans discrets (126 -> 157)
    readonly property color hudTrackEmpty: Qt.rgba(1, 1, 1, 0.10)
    readonly property color hudTick: Qt.rgba(1, 1, 1, 0.26)

    // Lignes de liste
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color separator: Qt.rgba(1, 1, 1, 0.14)

    // ---- Mouvements (ressorts Tahoe approchés) ----
    readonly property int durOpen: 360
    readonly property int durClose: 200
    readonly property int durExpand: 440
    readonly property int durCollapse: 320
}
