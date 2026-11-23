import QtQuick
import qs.common

// Module curseur 4x1 du Control Center ("Écran", "Son") ; sert aussi de HUD
// (Osd.qml : variante `hud` avec graduations). Cotes relevées sur une capture
// de macOS 26.0 (module 291 x 63 pt) : titre 13 pt (haut des capitales à 14 pt
// du bord), piste à 41,5 pt du haut, pictos centrés à 21 pt des bords.
CCTile {
    id: m

    property string title
    property string leftSymbol
    property int leftSize: 16
    property string rightSymbol
    property int rightSize: 17
    property real value: 0
    property bool accessory: false          // bouton rond à droite (AirPlay / sorties)
    property string accessorySymbol: "airplay.audio"
    property bool accessoryOn: false
    property bool hud: false                // variante HUD : graduations, cotes du HUD
    property bool sliderEnabled: true
    // Un clic sur le module (hors curseur / bouton) le déplie : titleClicked()
    property bool expandable: false
    readonly property bool dragging: slider.dragging
    signal moved(real v)
    signal accessoryClicked()
    signal titleClicked()

    implicitWidth: CCStyle.width
    implicitHeight: CCStyle.cell
    radius: CCStyle.radiusTile
    interactive: expandable && !hud
    onClicked: m.titleClicked()

    readonly property real rowY: hud ? 38 : 42
    readonly property real leftCenterX: hud ? 20 : 21
    readonly property real rightCenterX: accessory ? width - 57.5 : width - 21

    Text {
        renderType: Text.CurveRendering
        id: titleText
        x: 15.5
        y: m.hud ? 9 : 12
        width: parent.width - 2 * x
        text: m.title
        color: CCStyle.text
        font.family: Theme.font
        font.letterSpacing: CCStyle.tracking
        font.pixelSize: CCStyle.sliderTitleSize
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: m.titleClicked()
        }
    }

    Symbol {
        id: leftIcon
        name: m.leftSymbol
        size: m.leftSize
        color: CCStyle.text
        x: m.leftCenterX - width / 2
        y: m.rowY - height / 2 + (m.hud ? -3 : 0)
    }

    CCSlider {
        id: slider
        x: m.hud ? 30 : 31.5
        width: rightIcon.x + (rightIcon.width - rightIcon.paintedWidth) / 2 - 5 - x
        y: m.rowY - height / 2 + (m.hud ? 3 : 0)
        value: m.value
        showTicks: m.hud
        interactive: m.sliderEnabled && !m.hud
        opacity: m.sliderEnabled ? 1 : CCStyle.disabledOpacity
        onMoved: v => m.moved(v)
    }

    Symbol {
        id: rightIcon
        // largeur visible approximative du glyphe (les SVG ont une marge)
        readonly property real paintedWidth: size * 0.84
        name: m.rightSymbol
        size: m.rightSize
        color: CCStyle.text
        x: m.rightCenterX - width / 2
        y: m.rowY - height / 2 + (m.hud ? -3 : 0)
    }

    IconCircle {
        visible: m.accessory
        size: 25
        x: m.width - 14 - size
        y: m.rowY - size / 2
        symbol: m.accessorySymbol
        glyphSize: 17
        on: m.accessoryOn
        onClicked: m.accessoryClicked()
    }
}
