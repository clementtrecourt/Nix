import QtQuick
import qs.session

// Fournisseur de fond pour LiquidGlass (backdrop: "wallpaper") : le fond
// d'écran courant (session/WallpaperView : image utilisateur ou fond procédural
// Tahoe, avec ses fondus) rendu à la taille de l'écran, origine = coin
// haut-gauche de l'écran. Il n'est jamais affiché tel quel : chaque LiquidGlass
// n'en lit (ShaderEffectSource + sourceRect) que la région autour de lui, donc
// seul ce petit rectangle est rastérisé, et une seule fois tant que le fond ne
// change pas.
//
// Une instance par fenêtre suffit ; la passer à tous les verres de la fenêtre
// (backdropItem: wp) évite de décoder l'image plusieurs fois.
Item {
    id: root

    property var screen: null
    readonly property bool ready: true

    width: screen?.width ?? 0
    height: screen?.height ?? 0
    // Jamais affiché : les ShaderEffectSource des verres rendent quand même
    // un item invisible dans leur texture.
    visible: false

    WallpaperView {
        anchors.fill: parent
        // Décodage à la résolution de l'écran (le verre floute de toute façon)
        decodeSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
    }
}
