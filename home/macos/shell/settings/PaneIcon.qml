import QtQuick
import qs.common

// Pastille de panneau de Tahoe : carré à coins continus (≈ 0,26 × côté),
// dégradé vertical clair en haut, liseré intérieur clair d'un demi-point,
// pictogramme blanc (≈ 0,62 × côté). « Apple Intelligence & Siri » : dégradé
// multicolore.
Item {
    id: root

    property var spec: null            // entrée du catalogue (Nav.catalog)
    property int size: 20
    readonly property var colors: spec?.c ?? ["#A9A9AE", "#8A8A90"]

    width: size
    height: size

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.size * 0.26
        gradient: Gradient {
            GradientStop { position: 0; color: root.colors[0] }
            GradientStop { position: 1; color: root.colors[1] }
        }
        // Multicolore : diagonale chaude / froide par-dessus
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !!root.spec?.multi
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 0.62, 0.30, 0.85) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 0.35, 0.55, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(0.35, 0.55, 1, 0.85) }
            }
        }
        // Reflet du haut
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.20) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        // Liseré intérieur
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 0.5
            border.color: Qt.rgba(1, 1, 1, Theme.dark ? 0.22 : 0.30)
        }
        // Contour extérieur très léger (pastilles claires sur fond clair)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -0.5
            radius: parent.radius + 0.5
            color: "transparent"
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, Theme.dark ? 0.25 : 0.10)
        }
    }

    Symbol {
        anchors.centerIn: parent
        name: root.spec?.icon ?? ""
        size: Math.round(root.size * 0.66)
        color: root.spec?.glyph ?? "#FFFFFF"
    }
}
