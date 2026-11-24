import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// Ligne du formulaire groupé : libellé (13 pt) et sous-titre gris facultatif
// (11 pt, interligne 14) à gauche, contrôle à droite, séparateur fin inset de
// 10 pt au-dessus (sauf première ligne). Hauteur : 36 pt au moins, sinon
// contenu + 10 pt de part et d'autre (ligne à bouton : 44 pt, à icône : 42 pt).
//
// Icône de tête facultative : `pane` (pastille de panneau), `iconSource`
// (icône d'app), `symbol` (pictogramme gris), `dotColor` (point de statut).
// `chevron` : ligne de navigation (› à droite, toute la ligne cliquable).
Item {
    id: root

    property string title
    property string subtitle
    property string detail                // valeur grise à droite
    property var pane: null
    property string iconSource
    property string symbol
    property color symbolColor: SStyle.secondary
    property int iconSize: 20
    property color dotColor: "transparent"
    property bool chevron: false
    property bool clickable: chevron
    property bool dimmed: false
    property bool separator: Positioner.index > 0
    property real minHeight: SStyle.rowMin
    // Lignes hautes (vignettes, pastilles) : libellé en haut (centre à 18 pt)
    // et contrôle à `controlTop` du haut
    property bool alignTop: false
    // Décalage de l'icône et du libellé (case à cocher devant, Menu Bar)
    property real leadOffset: 0
    property real controlTop: SStyle.pad
    property alias control: ctl
    default property alias controls: ctl.data
    readonly property alias hovered: ma.containsMouse
    signal clicked()

    width: parent ? parent.width : 0
    implicitHeight: Math.max(minHeight, textCol.implicitHeight + 2 * SStyle.pad + 2,
                             ctl.implicitHeight + 2 * SStyle.pad,
                             lead.visible ? root.iconSize + 22 : 0)
    height: implicitHeight

    readonly property bool hasLead: !!pane || iconSource !== "" || symbol !== ""
    readonly property real textX: SStyle.pad + leadOffset + (hasLead ? iconSize + 8 : 0) + (dotColor.a > 0 ? 14 : 0)

    Rectangle {
        visible: root.separator
        x: SStyle.pad
        width: parent.width - 2 * SStyle.pad
        height: 1
        color: SStyle.separator
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        onClicked: root.clicked()
    }

    Item {
        id: lead
        visible: root.hasLead
        opacity: root.dimmed ? 0.5 : 1
        x: SStyle.pad + root.leadOffset
        width: root.iconSize
        height: root.iconSize
        anchors.verticalCenter: parent.verticalCenter
        PaneIcon {
            visible: !!root.pane
            spec: root.pane
            size: root.iconSize
        }
        IconImage {
            visible: root.iconSource !== ""
            anchors.fill: parent
            source: root.iconSource
            implicitSize: root.iconSize
        }
        Symbol {
            visible: root.symbol !== ""
            anchors.centerIn: parent
            name: root.symbol
            size: root.iconSize - 2
            color: root.symbolColor
        }
    }
    Rectangle {
        visible: root.dotColor.a > 0
        x: SStyle.pad + (root.hasLead ? root.iconSize + 8 : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: root.dotColor
    }

    Column {
        id: textCol
        x: root.textX
        width: Math.max(40, ctl.x - x - 12)
        y: root.alignTop ? 10 : Math.round((root.height - height) / 2)
        spacing: 1
        Text {
            width: parent.width
            text: root.title
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: SStyle.body
            color: root.dimmed ? SStyle.tertiary : SStyle.label
        }
        Text {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            linkColor: SStyle.link
            font.family: Theme.font
            font.pixelSize: SStyle.small
            lineHeight: 14
            lineHeightMode: Text.FixedHeight
            color: root.dimmed ? SStyle.tertiary : SStyle.secondary
        }
    }

    Row {
        id: ctl
        anchors.right: parent.right
        anchors.rightMargin: SStyle.pad
        y: root.alignTop ? root.controlTop : Math.round((root.height - height) / 2)
        spacing: 8
        layoutDirection: Qt.LeftToRight

        Text {
            visible: root.detail !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.detail
            font.family: Theme.font
            font.pixelSize: SStyle.body
            color: root.dimmed ? SStyle.tertiary : SStyle.secondary
        }
    }
    Symbol {
        id: chev
        visible: root.chevron
        anchors.right: parent.right
        anchors.rightMargin: SStyle.pad - 1
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron.right"
        size: 11
        color: SStyle.tertiary
    }
    // Le chevron décale les contrôles
    Binding { target: ctl; property: "anchors.rightMargin"; value: SStyle.pad + 18; when: root.chevron }
}
