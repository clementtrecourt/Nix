import QtQuick
import qs.common

// Bouton poussoir de Tahoe dans les formulaires : 24 pt de haut, coins de
// 7 pt, fond gris léger, texte 13 pt (capture 2x MacStories : « Reset Quick
// Keys… »). `prominent` : bouton bleu (par défaut d'une feuille).
Item {
    id: root

    property string text
    property bool prominent: false
    property bool enabledButton: true
    property real minWidth: 0
    signal clicked()

    implicitWidth: Math.max(minWidth, label.implicitWidth + 26)
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    opacity: enabledButton ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.prominent ? SStyle.accent : (ma.pressed ? SStyle.controlFillPressed : SStyle.controlFill)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.prominent && ma.pressed
            color: Qt.rgba(0, 0, 0, 0.15)
        }
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: SStyle.body
        color: root.prominent ? "#FFFFFF" : SStyle.label
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabledButton
        onClicked: root.clicked()
    }
}
