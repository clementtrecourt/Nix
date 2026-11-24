import QtQuick
import qs.common

// Module curseur 4x1 du Control Center ("Display", "Sound") ; sert aussi de HUD
// (Osd.qml : variante `hud` avec graduations). Cotes relevées sur la capture
// Apple de Tahoe 26 (support.apple.com, 1,96 px/pt, module 291 x 63 pt ;
// MacStories concordant) : titre 13 pt semibold (haut des capitales à 13,4 pt du
// bord, idem sur le HUD), piste et pictos centrés à ~41,8 pt du haut (42 ici :
// piste de 4 px sur pixels entiers).
// Display : soleil à 20,2 pt du bord gauche, piste de 31,6 pt à ~34 pt du bord
// droit, soleil à 21,7 pt du bord droit. Sound : haut-parleur à 19 pt, piste de
// 29,6 pt à ~71,5 pt du bord droit, haut-parleur à 57,5 pt du bord droit, bouton
// AirPlay (26 pt) centré à 26 pt du bord droit.
// Écran 1x : toutes les positions sont arrondies au pixel (net, sans flou).
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

    property real rowY: 42
    // Géométrie de la ligne (valeurs par défaut : module Display)
    property real leftCenterX: 20
    property real trackLeft: 32
    property real trackRightInset: 34       // fin de la piste, depuis le bord droit
    property real rightInset: 22            // centre du picto droit, depuis le bord droit
    readonly property real rightCenterX: width - rightInset

    Text {
        renderType: Text.NativeRendering
        id: titleText
        x: 15.5
        y: 10
        width: parent.width - 2 * x
        text: m.title
        color: CCStyle.text
        font.family: Theme.font
        font.letterSpacing: CCStyle.tracking
        font.pixelSize: CCStyle.sliderTitleSize
        // HUD : même graisse que « Sound » (MacStories, « Studio Display Speakers »)
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
        x: Math.round(m.leftCenterX - width / 2)
        y: Math.round(m.rowY - height / 2)
    }

    CCSlider {
        id: slider
        x: Math.round(m.trackLeft)
        width: Math.round(m.width - m.trackRightInset) - x
        // piste centrée sur rowY (HUD : crans dessous, piste décalée de -3 dans le curseur)
        y: Math.round(m.rowY - height / 2 + (m.hud ? 3 : 0))
        value: m.value
        showTicks: m.hud
        emptyColor: m.hud ? CCStyle.hudTrackEmpty : CCStyle.trackEmpty
        tickColor: m.hud ? CCStyle.hudTick : CCStyle.tick
        interactive: m.sliderEnabled && !m.hud
        opacity: m.sliderEnabled ? 1 : CCStyle.disabledOpacity
        onMoved: v => m.moved(v)
    }

    Symbol {
        id: rightIcon
        name: m.rightSymbol
        size: m.rightSize
        color: CCStyle.text
        x: Math.round(m.rightCenterX - width / 2)
        y: Math.round(m.rowY - height / 2)
    }

    IconCircle {
        visible: m.accessory
        size: 26
        x: m.width - 13 - size
        y: Math.round(m.rowY - size / 2)
        symbol: m.accessorySymbol
        glyphSize: 17
        on: m.accessoryOn
        onClicked: m.accessoryClicked()
    }
}
