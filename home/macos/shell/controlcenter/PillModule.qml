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
        x: 13.5
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

    // Largeur disponible pour le texte (calculée sur la géométrie du module, pas
    // sur la mise en page, pour éviter toute boucle de liaison)
    readonly property real textLeft: 13.5 + 35 + 7
    readonly property real textWidth: width - textLeft - 9
    // Mot le plus long du titre : s'il ne tient pas à 12 pt ("Concentration"),
    // on réduit le corps (11 puis 10 pt), avec au besoin un léger resserrement
    // (0,4 px max par lettre), plutôt que de couper le mot.
    FontMetrics {
        id: titleMetrics
        font.family: Theme.font
        font.pixelSize: CCStyle.titleSize
        font.weight: Font.DemiBold
    }
    readonly property string longestWord: title.split(" ").reduce((a, b) => b.length > a.length ? b : a, "")
    readonly property real longestWidth: titleMetrics.advanceWidth(longestWord)
    readonly property int titleFitSize: {
        const n = Math.max(1, longestWord.length);
        for (let px = CCStyle.titleSize; px > 10; px--)
            if (longestWidth * px / CCStyle.titleSize - 0.4 * n <= textWidth) return px;
        return 10;
    }
    readonly property real titleSpacing: {
        const w = longestWidth * titleFitSize / CCStyle.titleSize;
        return w <= textWidth ? CCStyle.tracking : Math.max(-0.4, (textWidth - w) / Math.max(1, longestWord.length));
    }

    Column {
        x: pill.textLeft
        width: pill.textWidth
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -0.5
        spacing: 0
        opacity: pill.disabled ? CCStyle.disabledOpacity : 1

        Text {
            renderType: Text.CurveRendering
            width: parent.width
            text: pill.title
            color: CCStyle.text
            font.family: Theme.font
            font.letterSpacing: pill.titleSpacing
            font.pixelSize: pill.titleFitSize
            font.weight: Font.DemiBold
            // Sans sous-titre, un titre long passe sur deux lignes ("Ne pas / déranger")
            wrapMode: pill.subtitle === "" ? Text.WordWrap : Text.NoWrap
            maximumLineCount: pill.subtitle === "" ? 2 : 1
            lineHeight: 0.92
            elide: Text.ElideRight
        }
        Text {
            renderType: Text.CurveRendering
            width: parent.width
            visible: text !== ""
            text: pill.subtitle
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.subtitleSize
            // Un nom de réseau long passe sur deux lignes ("TidBITS / Mesh"), comme sur Tahoe
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            lineHeight: 0.95
            elide: Text.ElideRight
        }
    }
}
