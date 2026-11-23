import QtQuick
import qs.common

// Bouton poussoir Tahoe : capsule (rayon = demi-hauteur), bouton par défaut en
// couleur d'accent, bouton secondaire en remplissage neutre translucide, liseré
// lumineux en haut (verre), assombri à l'appui.
Item {
    id: root

    property string text
    property bool isDefault: false
    property bool destructive: false
    property bool enabled: true
    property int fontSize: 13
    signal clicked()

    implicitHeight: 28
    implicitWidth: Math.max(84, label.implicitWidth + 32)
    opacity: enabled ? 1 : 0.45

    readonly property color base: isDefault
        ? (destructive ? Theme.red : Theme.accent)
        : (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07))

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: root.base
        // Reflet supérieur du verre
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.isDefault ? 0.16 : (Theme.dark ? 0.06 : 0.35)) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        border.width: root.isDefault ? 0 : 0.5
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "black"
        opacity: ma.pressed ? (root.isDefault ? 0.18 : 0.10) : 0
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: root.fontSize
        font.weight: root.isDefault ? Font.DemiBold : Font.Medium
        color: root.isDefault ? "white" : Theme.label
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
