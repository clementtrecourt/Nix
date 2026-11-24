import QtQuick
import qs.common

// Bouton d'une capsule de la barre d'outils : pictogramme SF Symbols 17 pt,
// pastille grise arrondie quand il est choisi (présentation courante) ou
// enfoncé ; chevron facultatif (menus déroulants : Grouper, Action).
Item {
    id: root

    property string symbol: ""
    property int symbolSize: FStyle.toolIcon
    property bool selected: false
    property bool chevron: false
    property string chevronSymbol: "chevron.down"
    property bool enabledButton: true
    property real buttonWidth: chevron ? 48 : FStyle.buttonWidth
    readonly property alias hovered: ma.containsMouse
    readonly property alias pressed: ma.pressed
    signal clicked()
    signal pressedAt(real x, real y)

    width: buttonWidth
    height: FStyle.buttonHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.selected || (ma.pressed && root.enabledButton) ? FStyle.toolSelected
               : (ma.containsMouse && root.enabledButton ? FStyle.toolHover : "transparent")
    }

    Row {
        anchors.centerIn: parent
        spacing: 3
        Symbol {
            name: root.symbol
            size: root.symbolSize
            anchors.verticalCenter: parent.verticalCenter
            color: root.enabledButton ? FStyle.toolIconColor : FStyle.toolIconDisabled
        }
        Symbol {
            visible: root.chevron
            name: root.chevronSymbol
            size: root.chevronSymbol === "chevron.down" ? 9 : 11
            anchors.verticalCenter: parent.verticalCenter
            color: root.enabledButton ? FStyle.toolIconColor : FStyle.toolIconDisabled
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledButton
        onPressed: (m) => root.pressedAt(m.x, m.y)
        onClicked: root.clicked()
    }
}
