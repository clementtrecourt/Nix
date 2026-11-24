import QtQuick
import qs.common

// Plaque du Dock : verre Liquid Glass commun (Glass), qui réfracte le fond
// d'écran (GlassBackdrop "wallpaper" de la fenêtre du Dock).
//
// Calibrage sur deux captures Tahoe 26 (Newsroom « Apple Music », Dock clair
// sur fond bleu ; Ars Technica, Dock sombre et clair) :
//  - intérieur : clair = fond flouté à peine éclairci (+20/255 sur un fond à
//    ~140 : teinte blanche faible) ; sombre = fond très légèrement assombri
//    (-3 à -9/255) ; la couleur du fond reste lisible (pas de voile laiteux) ;
//  - liseré d'un demi-point très lumineux en haut et en bas (+40 à +60/255),
//    flancs plus discrets ;
//  - ombre portée quasi invisible : le fond au-dessus de la plaque n'est
//    assombri que de ~5/255 en clair, pas du tout en sombre.
Item {
    id: root
    property real radius: 20

    Glass {
        anchors.fill: parent
        radius: root.radius
        tint: Theme.dark ? Qt.rgba(0.08, 0.08, 0.09, 0.16) : Qt.rgba(1, 1, 1, 0.16)
        // Liseré : tout le pourtour est net (flancs à ~60 % des arcs éclairés),
        // sans bande sombre dessous (aucune sur les captures du Dock)
        rimColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.60)
        rimWidth: 1.0
        rimBase: 0.75
        glowColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.18)
        shadeColor: "transparent"
        edgeDarken: 0.05
        edgeSaturate: 0.2
        shadowBlur: 0.5
        shadowOffset: 3
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.10 : 0.07)
    }
}
