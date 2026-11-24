import QtQuick
import Quickshell
import qs.common

// Bouton d'aide rond « ? » de Tahoe (20 pt), en bas à droite des panneaux.
Rectangle {
    property string url: "https://support.apple.com/guide/mac-help/welcome/mac"
    width: 20
    height: 20
    radius: 10
    color: ma.pressed ? SStyle.controlFillPressed : SStyle.controlFill
    Text {
        anchors.centerIn: parent
        text: "?"
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
        color: SStyle.label
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: Quickshell.execDetached(["xdg-open", parent.url]) }
}
