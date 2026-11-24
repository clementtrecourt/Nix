import QtQuick
import qs.common

// Module curseur 4x1 du Control Center ("Écran", "Son") ; sert aussi de HUD
// (Osd.qml : variante `hud` avec graduations). Cotes relevées sur la capture
// Apple de Tahoe 26 (module 291 x 63 pt) : titre 13 pt (haut des capitales à
// 13,4 pt du bord, idem sur le HUD), piste et pictos centrés à 41,5 pt du haut.
// Display : soleil à 22,5 pt du bord gauche, piste de 37 à 253 pt, soleil à
// 23,5 pt du bord droit. Sound : haut-parleur à 21 pt, piste de 34,5 à 212,5 pt,
// haut-parleur à 61 pt du bord droit, bouton AirPlay (26 pt) à 27 pt.
// HUD : 19,5 pt, piste de 31 à 261 pt, haut-parleur à 16 pt du bord droit,
// 17 points de graduation 6 pt sous la piste.
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

    readonly property real rowY: 41.5
    // Géométrie de la ligne (valeurs par défaut : module Display)
    property real leftCenterX: 22.5
    property real trackLeft: 37
    property real trackRightInset: 38       // fin de la piste, depuis le bord droit
    property real rightInset: 23.5          // centre du picto droit, depuis le bord droit
    readonly property real rightCenterX: width - rightInset

    Text {
        renderType: Text.CurveRendering
        id: titleText
        x: 15.5
        y: 10
        width: parent.width - 2 * x
        text: m.title
        color: CCStyle.text
        font.family: Theme.font
        font.letterSpacing: CCStyle.tracking
        font.pixelSize: CCStyle.sliderTitleSize
        // HUD : titre plus léger que « Display » / « Sound » (capture Tahoe)
        font.weight: m.hud ? Font.Medium : Font.DemiBold
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
        y: m.rowY - height / 2
    }

    CCSlider {
        id: slider
        x: m.trackLeft
        width: m.width - m.trackRightInset - x
        y: m.rowY - height / 2 + (m.hud ? 3 : 0)
        value: m.value
        showTicks: m.hud
        interactive: m.sliderEnabled && !m.hud
        opacity: m.sliderEnabled ? 1 : CCStyle.disabledOpacity
        onMoved: v => m.moved(v)
    }

    Symbol {
        id: rightIcon
        name: m.rightSymbol
        size: m.rightSize
        color: CCStyle.text
        x: m.rightCenterX - width / 2
        y: m.rowY - height / 2
    }

    IconCircle {
        visible: m.accessory
        size: 26
        x: m.width - 14 - size
        y: m.rowY - size / 2
        symbol: m.accessorySymbol
        glyphSize: 17
        on: m.accessoryOn
        onClicked: m.accessoryClicked()
    }
}
