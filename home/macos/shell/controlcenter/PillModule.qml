import QtQuick
import qs.common

// Module "pilule" 2x1 : pastille ronde (bascule) + titre + sous-titre.
// Clic sur la pastille = toggled() ; clic ailleurs = expand() (sous-panneau).
CCTile {
    id: pill

    property string title
    property string subtitle
    property string symbol
    property int glyphSize: 22
    property bool on: false
    property color onGlyph: CCStyle.blue
    property bool disabled: false
    signal toggled()
    signal expand()

    implicitWidth: CCStyle.span(2)
    implicitHeight: CCStyle.cell
    radius: height / 2
    interactive: !disabled
    onClicked: pill.expand()

    IconCircle {
        id: circle
        x: 13
        anchors.verticalCenter: parent.verticalCenter
        size: 35
        symbol: pill.symbol
        glyphSize: pill.glyphSize
        on: pill.on
        onGlyph: pill.onGlyph
        interactive: !pill.disabled
        opacity: pill.disabled ? CCStyle.disabledOpacity : 1
        onClicked: pill.toggled()
    }

    Column {
        anchors.left: circle.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -0.5
        spacing: 0
        opacity: pill.disabled ? CCStyle.disabledOpacity : 1

        // Mot le plus long du titre : s'il ne tient pas à 12 pt ("Concentration"),
        // on passe à 11 pt plutôt que de couper le mot.
        TextMetrics {
            id: longest
            font.family: Theme.font
            font.pixelSize: CCStyle.titleSize
            font.weight: Font.DemiBold
            text: pill.title.split(" ").reduce((a, b) => b.length > a.length ? b : a, "")
        }
        Text {
            width: parent.width
            text: pill.title
            color: CCStyle.text
            font.family: Theme.font
            readonly property bool tooLong: longest.advanceWidth > width
            font.letterSpacing: tooLong ? -0.25 : CCStyle.tracking
            font.pixelSize: tooLong ? CCStyle.titleSize - 1 : CCStyle.titleSize
            font.weight: Font.DemiBold
            // Sans sous-titre, un titre long passe sur deux lignes ("Ne pas / déranger")
            wrapMode: pill.subtitle === "" ? Text.WordWrap : Text.NoWrap
            maximumLineCount: pill.subtitle === "" ? 2 : 1
            lineHeight: 0.92
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: pill.subtitle
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.subtitleSize
            elide: Text.ElideRight
        }
    }
}
