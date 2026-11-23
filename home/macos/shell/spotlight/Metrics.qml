pragma Singleton

import QtQuick
import Quickshell

// Dimensions de Spotlight (macOS 26 Tahoe), en points.
//
// Relevées sur les vidéos officielles d'Apple (Newsroom WWDC25, « Spotlight
// search » et « Spotlight actions ») et sur des captures Retina de la version
// finale (MacRumors) : toutes les cotes sont proportionnelles à la hauteur H
// du champ (≈ 56 pt), ce qui permet de recouper les sources entre elles :
//   largeur du champ seul        ≈ 11,5 H   (= largeur du panneau de résultats)
//   boutons de mode              = H (ronds), espacés de ≈ 0,19 H
//   loupe centrée à              ≈ 0,57 H du bord gauche ; texte à ≈ 1,08 H
//   ligne de résultat            ≈ 1,0 H (deux lignes : titre + détail)
//   icône de résultat            ≈ 0,58 H
//   vue Applications             : 5 colonnes, icônes ≈ 1,08 H, rangées ≈ 1,9 H
Singleton {
    // Champ de recherche : capsule Liquid Glass
    readonly property int barHeight: 56
    readonly property int barRadius: barHeight / 2
    // Largeur totale du groupe (champ + boutons de mode, ou panneau de résultats)
    readonly property int groupWidth: 646
    // Boutons de mode ronds à droite du champ
    readonly property int buttonSize: 56
    readonly property int buttonSpacing: 10
    readonly property int buttonGap: 10          // entre le champ et le 1er bouton
    readonly property int buttonsWidth: buttonGap + 4 * buttonSize + 3 * buttonSpacing
    // Position verticale : haut du champ à ~23 % de la hauteur d'écran
    readonly property real topRatio: 0.23

    readonly property int fieldFontSize: 26
    // Loupe / symbole du mode dans le champ (≈ 0,45 H de large une fois
    // dessiné : les SVG occupent ~70 % de leur cadre) et symboles des boutons
    readonly property int glyphSize: 30
    readonly property int buttonGlyphSize: 27
    readonly property int leadCenter: 31         // centre de la loupe depuis le bord
    readonly property int textX: 59              // début du texte du champ
    readonly property int sidePad: 19            // retrait des séparateurs / pastilles

    // Liste de résultats (lignes à deux niveaux : titre + détail)
    readonly property int rowHeight: 54
    readonly property int rowIcon: 32
    readonly property int rowInset: 8
    readonly property int rowRadius: 14
    readonly property int titleSize: 15
    readonly property int detailSize: 13
    readonly property int listPadTop: 6
    readonly property int listPadBottom: 8

    // Pastilles de filtre (sous le champ)
    readonly property int chipHeight: 26
    readonly property int chipFontSize: 13
    readonly property int chipSpacing: 8
    readonly property int chipsTop: 10           // sous le séparateur
    readonly property int chipsBottom: 8

    // Grilles (Applications, Fichiers)
    readonly property int gridIcon: 60
    readonly property int gridColumns: 5
    readonly property int gridCellHeight: 106
    readonly property int gridLabelSize: 13
    // Hauteur max du panneau de la vue Applications (≈ carré, comme Tahoe)
    readonly property int appsPanelHeight: 560
}
