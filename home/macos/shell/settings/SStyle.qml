pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Mesures et couleurs de Réglages Système (System Settings) de macOS Tahoe 26,
// relevées sur des captures :
//  - MacStories « macOS 26 Tahoe: The MacStories Review » (Spotlight, Menu Bar ;
//    captures 2x CleanShot : 2 px = 1 pt) ;
//  - Apple mac-help mh15217 / mchldfdf4f86 / mchlp3013 (Appearance, Wallpaper ;
//    1,61 px/pt, étalon = pas des feux tricolores 23 pt) ;
//  - Eclectic Light « Appearance matters » (mode sombre).
Singleton {
    readonly property bool dark: Theme.dark

    // ---- Fenêtre ----
    readonly property int windowWidth: 715          // largeur fixe (comme sur Mac)
    readonly property int windowHeight: 660
    readonly property int minHeight: 420
    readonly property int windowRadius: 26
    // Fond du contenu : blanc en clair (relevé 255), gris sombre en sombre
    readonly property color contentBg: dark ? "#272B2E" : "#FFFFFF"

    // ---- Barre latérale (verre inset) ----
    readonly property int sidebarInset: 8
    readonly property int sidebarWidth: 215
    readonly property int sidebarRadius: 18
    readonly property int searchX: 10
    readonly property real searchY: 54          // depuis le haut de la barre
    readonly property int searchHeight: 28
    readonly property color searchFill: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.095)
    readonly property int cardCenterY: 110      // centre de la carte utilisateur (repère barre)
    readonly property int avatarSize: 38
    readonly property int avatarX: 16
    readonly property int cardTextX: 62
    readonly property int firstRowCenterY: 162  // premier panneau (Wi-Fi)
    // Taille des icônes de la barre latérale (Appearance > Sidebar icon size)
    readonly property string sidebarSize: Prefs.v.sidebarIconSize ?? "medium"
    readonly property int row: sidebarSize === "small" ? 24 : sidebarSize === "large" ? 38 : 32   // pas des lignes
    readonly property int sidebarFont: sidebarSize === "small" ? 11 : sidebarSize === "large" ? 15 : 13
    readonly property int groupGap: 13             // espace supplémentaire entre groupes
    readonly property int rowIcon: sidebarSize === "small" ? 16 : sidebarSize === "large" ? 24 : 20
    readonly property int rowIconCenterX: 26
    readonly property int rowTextX: sidebarSize === "small" ? 36 : sidebarSize === "large" ? 46 : 42
    readonly property int pillInset: 10
    readonly property int pillRadius: 9
    // Sélection : bleu plein + texte blanc (fenêtre active), gris sinon
    readonly property color selection: dark ? "#1E5CD6" : "#0763E0"
    readonly property color selectionInactive: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color sidebarText: dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.86)

    // ---- Barre de titre ----
    readonly property int titleCenterY: 26          // centre des feux / capsule / titre (26,5)
    readonly property int capsuleGap: 8             // capsule ‹ › après la barre latérale
    readonly property int titleSize: 15

    // ---- Formulaire groupé ----
    readonly property int contentTop: 52
    readonly property int contentSide: 20
    readonly property int groupRadius: 13
    readonly property int groupSpacing: 10
    readonly property int pad: 10                   // marge interne gauche / droite
    readonly property int rowMin: 36
    readonly property color groupFill: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.032)
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.055)
    readonly property color label: dark ? Qt.rgba(1, 1, 1, 0.86) : Qt.rgba(0, 0, 0, 0.85)
    readonly property color secondary: dark ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(0, 0, 0, 0.50)
    readonly property color tertiary: dark ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0, 0, 0, 0.26)
    readonly property color link: dark ? "#3D9BFF" : "#0068DA"
    readonly property int body: 13
    readonly property int small: 11

    // ---- Contrôles ----
    readonly property color accent: Prefs.accentColor
    readonly property color controlFill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.075)
    readonly property color controlFillPressed: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color switchOff: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color popupCircle: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.075)
    readonly property color sliderTrack: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)

    // Statuts (points de connexion)
    readonly property color green: dark ? "#30D158" : "#28C840"
    readonly property color orange: dark ? "#FF9F0A" : "#FF9500"
    readonly property color red: dark ? "#FF453A" : "#FF3B30"
    readonly property color gray: dark ? "#8E8E93" : "#AEAEB2"
}
