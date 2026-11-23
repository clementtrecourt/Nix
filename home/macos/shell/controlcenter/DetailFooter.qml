import QtQuick
import qs.common

// Pied d'un module déplié : séparateur + lien "Réglages Wi-Fi…".
Item {
    id: f

    property string text
    signal clicked()

    implicitWidth: CCStyle.width
    implicitHeight: 11 + 30 + 6

    Rectangle {
        x: 16
        y: 5
        width: parent.width - 32
        height: 1
        color: CCStyle.separator
    }

    Item {
        y: 11
        width: parent.width
        height: 30

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: CCStyle.radiusRow
            color: CCStyle.rowHover
            opacity: ma.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }
        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: f.text
            color: CCStyle.text
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.rowSize
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: f.clicked()
        }
    }
}
