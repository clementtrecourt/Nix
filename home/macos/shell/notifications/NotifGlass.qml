import QtQuick
import qs.common

// Verre des notifications et des widgets.
//
// `tint` = aspect final du verre, comme un voile posé sur le fond flouté :
//  - sans réfraction (fenêtre sans GlassBackdrop) : Rectangle peint sous le
//    Glass commun (teinte transparente : liseré, lueur et ombre seulement) ;
//  - avec réfraction : le verre est opaque (fond réfracté) ; la teinte passe en
//    voile (`overlay`) composé par-dessus, et la teinte adaptative du verre est
//    coupée (`adaptive: 0`) : le résultat ne dépend que de `tint`, comme sans
//    réfraction (relevé Tahoe clair : blanc ~70 % sur le fond, chrominance
//    du fond gardée).
//
// La taille du verre est arrondie au pixel PAIR : le shader commun produit un
// NaN (ligne transparente) quand le centre du verre tombe pile au centre d'un
// pixel (normale dégénérée en précision moyenne).
Item {
    id: root

    property real radius: 22
    property color tint: Theme.glass
    property bool shadowEnabled: true
    property real shadowBlur: 1.0
    property int shadowOffset: 8
    // Sans réfraction (flou Hyprland), deux ombres superposées (carte + lamelle,
    // widget + carte) doivent rester sous ignore_alpha (0.05) : sinon halo
    // flouté autour du verre. Avec réfraction (namespace sans flou) : libre.
    property real shadowMax: 0.024
    property real shadowStrength: Theme.dark ? 0.30 : 0.14
    readonly property bool refracting: glass.refracting
    default property alias content: contentItem.data

    Rectangle {
        anchors.fill: glass
        radius: root.radius
        color: root.tint
        antialiasing: true
        visible: !glass.refracting
    }

    Glass {
        id: glass
        width: 2 * Math.round(root.width / 2)
        height: 2 * Math.round(root.height / 2)
        overlay: refracting ? root.tint : "transparent"
        radius: root.radius
        tint: "transparent"
        adaptive: 0
        shadowEnabled: root.shadowEnabled
        shadowBlur: root.shadowBlur
        shadowOffset: root.shadowOffset
        shadowColor: Qt.rgba(0, 0, 0, root.shadowStrength)
        shadowMax: refracting ? 1.0 : root.shadowMax
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
