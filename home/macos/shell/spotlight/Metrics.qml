pragma Singleton

import QtQuick
import Quickshell

// Dimensions de Spotlight (macOS 26 Tahoe), en points.
Singleton {
    // Champ de recherche : capsule Liquid Glass
    readonly property int barHeight: 54
    readonly property int barRadius: barHeight / 2
    // Largeur totale du groupe (champ + boutons de mode, ou panneau de résultats)
    readonly property int groupWidth: 740
    // Boutons de mode ronds à droite du champ
    readonly property int buttonSize: 54
    readonly property int buttonSpacing: 8
    readonly property int buttonGap: 12          // entre le champ et le 1er bouton
    readonly property int buttonsWidth: buttonGap + 4 * buttonSize + 3 * buttonSpacing
    // Position verticale : haut du champ à ~24 % de la hauteur d'écran
    readonly property real topRatio: 0.24

    readonly property int fieldFontSize: 22
    readonly property int glyphSize: 21

    // Liste de résultats
    readonly property int rowHeight: 40
    readonly property int topRowHeight: 52
    readonly property int headerHeight: 28
    readonly property int rowInset: 8
    readonly property int rowRadius: 10
    readonly property int listPadTop: 4
    readonly property int listPadBottom: 10

    // Grilles (Applications, Fichiers)
    readonly property int gridIcon: 64
    readonly property int gridColumns: 7
    readonly property int gridCellHeight: 104
    readonly property int chipHeight: 28
}
