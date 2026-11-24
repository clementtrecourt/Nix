import QtQuick
import qs.common

// Module rond 1x1 (Recopie de l'écran, Stage Manager, Mode sombre...).
// on = disque blanc et glyphe bleu (couleur d'accent), comme les bascules de
// Tahoe (pastilles Wi-Fi / Bluetooth / AirDrop allumées).
CCTile {
    id: m

    property string symbol
    property int glyphSize: 32
    property bool on: false
    property bool disabled: false

    implicitWidth: CCStyle.cell
    implicitHeight: CCStyle.cell
    radius: width / 2
    interactive: !disabled
    glassVisible: !on

    // Fond blanc quand le contrôle est actif
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: CCStyle.circleOn
        opacity: m.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Symbol {
        anchors.centerIn: parent
        name: m.symbol
        size: m.glyphSize
        color: m.on ? CCStyle.blue : CCStyle.text
        opacity: m.disabled ? CCStyle.disabledOpacity : 1
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
