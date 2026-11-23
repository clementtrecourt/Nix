import QtQuick
import qs.common

// Ligne d'une liste de module déplié (réseau, appareil, sortie audio...) :
// pastille ronde (bleue si actif), libellé, accessoire à droite.
Item {
    id: row

    property string symbol
    property int glyphSize: 16
    property string text
    property string detail                  // texte secondaire à droite (batterie, "Connexion…")
    property string trailingSymbol          // lock.fill, checkmark...
    property bool active: false             // connecté / sélectionné
    property bool busy: false
    property bool showIcon: true
    signal clicked()

    implicitWidth: CCStyle.width
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        radius: CCStyle.radiusRow
        color: CCStyle.rowHover
        opacity: ma.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    IconCircle {
        id: icon
        visible: row.showIcon
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 26
        symbol: row.symbol
        glyphSize: row.glyphSize
        on: row.active
        onColor: CCStyle.blue
        onGlyph: "white"
        interactive: false
        opacity: row.busy ? 0.55 : 1
        SequentialAnimation on opacity {
            running: row.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 500 }
            NumberAnimation { to: 0.9; duration: 500 }
        }
    }

    Text {
        anchors.left: row.showIcon ? icon.right : parent.left
        anchors.leftMargin: row.showIcon ? 9 : 16
        anchors.right: trailing.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.text
        color: CCStyle.text
        font.family: Theme.font
        font.letterSpacing: CCStyle.tracking
        font.pixelSize: CCStyle.rowSize
        elide: Text.ElideRight
    }

    Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Text {
            visible: row.detail !== ""
            text: row.detail
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Symbol {
            visible: row.trailingSymbol !== ""
            name: row.trailingSymbol
            size: 13
            color: CCStyle.textSecondary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
    }
}
