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
//
// Recalage (captures finales macOS 26 : MacRumors « Do More With Spotlight »,
// Cult of Mac « Spotlight-Applications / Spotlight-Actions ») :
//   texte du champ : hauteur de capitale ≈ 0,375 H  -> 28 px
//   titre de résultat : capitale ≈ 12,7 pt (0,23 H) -> Inter 18 px ; détail :
//   capitale ≈ 11 pt -> 15 px (Cult of Mac « Spotlight-Actions »,
//   « Spotlight-Clipboard », MacMagazine « lista »)
//   pas des lignes ≈ 1,02 H (57 pt), sélection grise neutre (pas d'accent)
//   boutons : écart champ/bouton et entre boutons ≈ 0,22 H (12 pt) ; avec les
//   boutons, le groupe dépasse le panneau seul de ≈ 31 pt vers la droite
//   pastilles : 24 pt de haut, texte 15 px
Singleton {
    // Champ de recherche : capsule Liquid Glass
    readonly property int barHeight: 56
    readonly property int barRadius: barHeight / 2
    // Largeur totale du groupe (champ + boutons de mode, ou panneau de résultats)
    readonly property int groupWidth: 646
    // Boutons de mode ronds à droite du champ
    readonly property int buttonSize: 56
    readonly property int buttonSpacing: 12
    readonly property int buttonGap: 12          // entre le champ et le 1er bouton
    readonly property int buttonsWidth: buttonGap + 4 * buttonSize + 3 * buttonSpacing
    // Débord à droite du groupe quand les boutons sont sortis
    readonly property int buttonsOverhang: 31
    // Largeur de la capsule quand les boutons sont sortis (≈ 405 pt)
    readonly property int barWidthWithButtons: groupWidth + buttonsOverhang - buttonsWidth
    // Position verticale : haut du champ à ~23 % de la hauteur d'écran
    readonly property real topRatio: 0.23

    readonly property int fieldFontSize: 28
    // Loupe / symbole du mode dans le champ (≈ 0,45 H de large une fois
    // dessiné : les SVG occupent ~70 % de leur cadre) et symboles des boutons
    readonly property int glyphSize: 30
    readonly property int buttonGlyphSize: 27
    readonly property int leadCenter: 32         // centre de la loupe depuis le bord
    readonly property int textX: 62              // début du texte du champ
    readonly property int sidePad: 19            // retrait des séparateurs / pastilles

    // Liste de résultats (lignes à deux niveaux : titre + détail)
    readonly property int rowHeight: 57
    // Cadre de l'icône : les icônes du thème ont une marge interne (dessin
    // ≈ 0,88 x cadre) -> dessin visible de 30 pt comme Tahoe
    readonly property int rowIcon: 34
    readonly property int rowInset: 9
    readonly property int rowRadius: 14
    readonly property int titleSize: 18
    readonly property int detailSize: 15
    readonly property int listPadTop: 0
    readonly property int listPadBottom: 8

    // Pastilles de filtre (sous le champ)
    readonly property int chipHeight: 24
    readonly property int chipFontSize: 15
    readonly property int chipSpacing: 9
    readonly property int chipsTop: 10           // sous le séparateur
    readonly property int chipsBottom: 11

    // Grilles (Applications, Fichiers)
    // Cadre 68 -> dessin visible de 60 pt (Safari : 120 px à 2x, Cult of Mac)
    readonly property int gridIcon: 68
    readonly property int gridColumns: 5
    readonly property int gridCellHeight: 106
    readonly property int gridLabelSize: 13
    // Hauteur max du panneau de la vue Applications (≈ carré, comme Tahoe)
    readonly property int appsPanelHeight: 560

    // En-têtes de section de la liste (vue Actions : « Suggestions », nom d'app)
    readonly property int headerHeight: 35
    readonly property int headerFontSize: 14

    // Vue Fichiers : vignettes jusqu'à ≈ 68 pt, noms sur deux lignes, pas des
    // rangées ≈ 130 pt (Cult of Mac « Spotlight-Files »)
    readonly property int fileCellHeight: 130

    // Complétion du meilleur résultat dans le champ (« — The Edinburgh
    // Minute ») : capsule grise de 30 pt, texte ≈ 0,9 x titre de résultat
    readonly property int completionHeight: 30
    readonly property int completionFontSize: 16
    // Icône du résultat choisi, à l'extrémité droite du champ
    readonly property int fieldIcon: 32

    // « Add quick keys » (vue Actions) : capsule de 18 pt, texte 11 px
    readonly property int quickKeysHeight: 18
    readonly property int quickKeysFontSize: 11
    // Bouton copier du presse-papiers : rond de 26 pt
    readonly property int copyButton: 26
}
