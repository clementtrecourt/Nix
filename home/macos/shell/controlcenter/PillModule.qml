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

    // Pastille de 37 pt concentrique à l'extrémité du module (13 pt de marge),
    // texte à 55,5 pt du bord : relevé sur la capture Apple (Wi-Fi « Home »).
    IconCircle {
        id: circle
        x: (pill.height - size) / 2
        anchors.verticalCenter: parent.verticalCenter
        size: 37
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
    readonly property real textLeft: 55.5
    readonly property real textWidth: width - textLeft - 9
    // Mot le plus long du titre : s'il ne tient pas à 13 pt,
    // on réduit le corps (12 puis 11 pt), avec au besoin un léger resserrement
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
        for (let px = CCStyle.titleSize; px > 11; px--)
            if (longestWidth * px / CCStyle.titleSize - 0.4 * n <= textWidth) return px;
        return 11;
    }
    readonly property real titleSpacing: {
        const w = longestWidth * titleFitSize / CCStyle.titleSize;
        return w <= textWidth ? CCStyle.tracking : Math.max(-0.4, (textWidth - w) / Math.max(1, longestWord.length));
    }

    // Le titre entier tient-il sur une ligne ? Sinon deux lignes ("Do Not /
    // Disturb"), avec ou sans sous-titre (Tahoe : « Do Not / Disturb / On »)
    readonly property bool twoLineTitle: titleMetrics.advanceWidth(title) * titleFitSize / CCStyle.titleSize > textWidth

    // Lignes de base relevées : titre à 28 pt du haut, sous-titre 16,4 pt plus
    // bas ; titre sur deux lignes : pas de 14,8 pt, sous-titre 14,3 pt plus bas
    Column {
        x: pill.textLeft
        width: pill.textWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: pill.twoLineTitle ? 0 : 2.5
        opacity: pill.disabled ? CCStyle.disabledOpacity : 1

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            text: pill.title
            color: CCStyle.text
            font.family: Theme.font
            font.letterSpacing: pill.titleSpacing
            font.pixelSize: pill.titleFitSize
            font.weight: Font.DemiBold
            // Un titre long passe sur deux lignes ("Do Not / Disturb")
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            lineHeight: pill.twoLineTitle ? 0.94 : 1
            elide: Text.ElideRight
        }
        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: text !== ""
            text: pill.subtitle
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.subtitleSize
            font.weight: Font.Medium
            // Un nom de réseau long passe sur deux lignes ("TidBITS / Mesh"), comme
            // sur Tahoe (une seule si le titre en occupe déjà deux)
            wrapMode: Text.WordWrap
            maximumLineCount: pill.twoLineTitle ? 1 : 2
            lineHeight: 0.95
            elide: Text.ElideRight
        }
    }
}
