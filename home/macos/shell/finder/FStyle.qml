pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Mesures et couleurs du Finder de macOS Tahoe 26, relevées sur des captures
// (MacStories « macOS 26 Tahoe: The MacStories Review », Apple « Use the Finder
// on Mac », mac-help mchlp2605 / mchlp1745) : texte de la barre latérale = 13 pt
// sert d'étalon (≈ 1,42 px/pt sur la capture MacStories en présentation Liste).
Singleton {
    readonly property bool dark: Theme.dark

    // ---- Fenêtre ----
    readonly property int windowRadius: 26
    // Fond du contenu (controlBackgroundColor)
    readonly property color contentBg: dark ? "#2B2C2E" : "#FFFFFF"
    readonly property int minWidth: 520
    readonly property int minHeight: 300

    // ---- Barre latérale flottante (verre inset) ----
    readonly property int sidebarInset: 8
    readonly property int sidebarWidth: 220
    readonly property int sidebarRadius: 18
    readonly property int sidebarRow: 32          // pas des lignes (32 pt, capture 2x de Daring Fireball)
    readonly property int sidebarPillHeight: 30
    readonly property int sidebarPillRadius: 10
    readonly property real sidebarIconX: 18         // depuis le bord de la barre (pixel entier : net en 1x)
    readonly property int sidebarTextX: 46
    readonly property int sidebarIcon: 17
    // Teinte posée sur le bureau flouté par Hyprland (fenêtre transparente sous
    // la plaque) : DF natif 2x, (255, 240, 251) sur fond rose ; Apple (251, 249, 248)
    readonly property color sidebarTint: dark ? Qt.rgba(0.16, 0.16, 0.17, 0.74) : Qt.rgba(0.975, 0.975, 0.98, 0.80)
    readonly property color sidebarSelection: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color sidebarHeader: dark ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(0, 0, 0, 0.42)

    // ---- Feux tricolores (dans la barre latérale) ----
    readonly property int lightSize: 14
    readonly property int lightGap: 9
    readonly property real lightX: 19               // depuis le bord de la fenêtre (centre à 26 pt, pixel entier)
    readonly property int lightY: 19

    // ---- Barre d'outils ----
    readonly property int toolbarHeight: 52
    readonly property int capsuleHeight: 36
    readonly property int capsuleY: 8
    readonly property int capsulePad: 4
    readonly property int buttonWidth: 35
    readonly property int columnRow: 22
    readonly property int buttonHeight: 28
    readonly property int capsuleGap: 10
    readonly property int toolIcon: 17
    readonly property color toolIconColor: dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.70)
    readonly property color toolIconDisabled: dark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.24)
    readonly property color toolSelected: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color toolHover: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color capsuleTint: dark ? Qt.rgba(0.20, 0.20, 0.21, 0.55) : Qt.rgba(1, 1, 1, 0.72)
    readonly property int titleSize: 15

    // ---- Présentation Liste ----
    readonly property int listRow: 20
    readonly property int listHeader: 24
    readonly property int listInset: 10           // retrait des pastilles de ligne
    readonly property int listIcon: 16
    readonly property int listIndent: 18
    readonly property color stripe: dark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(0, 0, 0, 0.035)
    readonly property color headerText: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.50)
    readonly property color gridLine: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color secondaryText: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.50)

    // ---- Sélection (alternateSelectedControlColor) ----
    readonly property color selection: dark ? "#0A59CC" : "#116AE2"
    // Libellé et icône de l'élément choisi de la barre latérale
    readonly property color sidebarAccent: dark ? "#0A84FF" : "#0674FF"
    readonly property color selectionInactive: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color selectionIcon: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)

    // ---- Présentation Icônes ----
    readonly property int iconSize: 64
    readonly property int iconCellW: 112
    readonly property int iconCellH: 112
    readonly property int iconText: 12
    // Largeur de retour à la ligne des noms (fixe : seule la place libre de la
    // grille varie avec la fenêtre). « Full Floor Plan.pdf » tient sur une
    // ligne, « Exhibition Program.pdf » non (capture Apple mchlp1745).
    readonly property int iconTextW: 104

    // ---- Barres du bas ----
    readonly property int pathBarHeight: 26
    readonly property int statusBarHeight: 26
}
