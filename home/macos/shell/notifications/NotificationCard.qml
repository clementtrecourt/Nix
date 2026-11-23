import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common

// Carte de notification macOS Tahoe (bannière et Centre de notifications).
//
//  ┌───────────────────────────────────────────────┐
//  │ [icône]  Titre (semi-gras)          maintenant │
//  │          Corps du message, jusqu'à 4 lignes…   │
//  └───────────────────────────────────────────────┘
//    └───────── lamelles de la pile (même app) ──┘
//
// Au survol : bouton × en haut à gauche (à cheval sur le coin), et l'heure laisse
// place à un chevron qui déplie les actions de la notification.
Item {
    id: card

    property NotifEntry entry
    property int stackCount: 1          // nb de notifications de la pile (lamelles)
    property bool closable: true
    property bool interactive: true
    // Le × efface toute la pile ("Tout effacer" au survol, comme macOS)
    property bool clearAllMode: false

    signal clicked()
    signal closeClicked()

    readonly property bool hovered: (hover.hovered || NotifStore.debugHover) && interactive
    property bool actionsOpen: false
    readonly property bool showActions: hasActions && (actionsOpen || NotifStore.debugActions)
    readonly property bool hasActions: entry && entry.actions.length > 0

    // ---- Géométrie Tahoe ----
    readonly property int radius: 22
    readonly property int padH: 12
    readonly property int padV: 12
    readonly property int iconSize: 38
    readonly property int peek: 9               // dépassement de chaque lamelle
    readonly property int slivers: Math.min(stackCount - 1, 2)

    width: 344
    implicitHeight: plate.height + stackPeek
    property real stackPeek: slivers * peek
    Behavior on stackPeek { NumberAnimation { duration: Theme.durMed * NotifStore.slow; easing.type: Easing.OutCubic } }

    onHoveredChanged: if (!hovered) actionsOpen = false

    // ---- Lamelles de la pile (derrière) ----
    // Le verre est translucide : chaque lamelle est découpée pour ne montrer que
    // la partie qui dépasse sous la carte (ou la lamelle) précédente.
    Repeater {
        model: 2
        Item {
            id: sliver
            required property int index
            readonly property int level: index + 1
            readonly property bool active: card.slivers >= level
            // Haut de la zone visible : bas de l'élément au-dessus (moins l'arrondi)
            readonly property real clipTop: plate.height + (level - 1) * card.peek - 3
            z: -level
            x: level * 12
            y: clipTop
            width: card.width - level * 2 * 12
            height: card.peek + 3 + 16      // + place pour l'ombre
            clip: true
            visible: opacity > 0
            opacity: active ? (level === 1 ? 0.9 : 0.7) : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed * NotifStore.slow } }

            Glass {
                width: parent.width
                height: 44
                // Bas de la lamelle : peek px sous l'élément du dessus
                y: (sliver.active ? card.peek + 3 : 0) - height
                Behavior on y { NumberAnimation { duration: Theme.durMed * NotifStore.slow; easing.type: Easing.OutCubic } }
                radius: card.radius - sliver.level * 4
                shadowOffset: 3
                shadowBlur: 0.5
            }
        }
    }

    // ---- Plaque principale ----
    Glass {
        id: plate
        width: card.width
        height: Math.max(card.iconSize, textCol.implicitHeight) + card.padV * 2 + actionsBox.height
        radius: card.radius
        Behavior on height { NumberAnimation { duration: Theme.durMed * NotifStore.slow; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            enabled: card.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }

        // Icône d'app, ou avatar rond + pastille d'app (style "communication")
        Item {
            id: iconBox
            x: card.padH
            width: card.iconSize
            height: card.iconSize
            y: card.padV + (Math.max(card.iconSize, textCol.implicitHeight) - card.iconSize) / 2

            IconImage {
                anchors.fill: parent
                visible: !card.entry || !card.entry.image
                source: card.entry ? card.entry.appIcon : ""
                asynchronous: true
                mipmap: true
            }
            ClippingRectangle {
                visible: !!(card.entry && card.entry.image)
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: Theme.fill
                Image {
                    anchors.fill: parent
                    source: card.entry ? card.entry.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(96, 96)
                    smooth: true
                }
            }
            IconImage {
                visible: !!(card.entry && card.entry.image)
                width: 18
                height: 18
                x: parent.width - 15
                y: parent.height - 15
                source: card.entry ? card.entry.appIcon : ""
                asynchronous: true
                mipmap: true
            }
        }

        // Colonne de texte
        ColumnLayout {
            id: textCol
            x: iconBox.x + card.iconSize + 10
            y: card.padV
            width: plate.width - x - card.padH - 2
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: card.entry ? (card.entry.summary || card.entry.appName) : ""
                    color: Theme.label
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }
                Item {
                    Layout.preferredWidth: Math.max(timeLabel.implicitWidth, card.hasActions && card.hovered ? 20 : 0)
                    Layout.preferredHeight: 17
                    Text {
                        id: timeLabel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.entry ? NotifStore.relTime(card.entry.time) : ""
                        color: Theme.labelSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                        opacity: card.hasActions && card.hovered ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    }
                    // Chevron "Options" : déplie les actions
                    Rectangle {
                        id: chevronBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: chevronMouse.containsMouse ? Theme.fillHover : Theme.fill
                        opacity: card.hasActions && card.hovered ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        Symbol {
                            anchors.centerIn: parent
                            name: card.showActions ? "chevron.up" : "chevron.down"
                            size: 10
                            color: Theme.label
                        }
                        MouseArea {
                            id: chevronMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: card.actionsOpen = !card.actionsOpen
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.entry ? (card.entry.summary ? card.entry.body : "") : ""
                color: Theme.label
                opacity: 0.92
                font.family: Theme.font
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: card.showActions ? 12 : 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
                lineHeight: 1.04
            }
        }

        // Actions (dépliées par le chevron) : capsules côte à côte, façon Tahoe
        Item {
            id: actionsBox
            anchors.bottom: parent.bottom
            anchors.bottomMargin: card.padV
            x: textCol.x
            width: textCol.width
            height: card.showActions ? 38 : 0
            clip: true
            opacity: card.showActions ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed * NotifStore.slow } }

            Row {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8
                Repeater {
                    model: card.entry ? card.entry.actions : []
                    Rectangle {
                        required property var modelData
                        width: (actionsBox.width - (card.entry.actions.length - 1) * 8) / card.entry.actions.length
                        height: 28
                        radius: 14
                        color: actMouse.pressed ? Qt.rgba(1, 1, 1, Theme.dark ? 0.24 : 0.6)
                             : actMouse.containsMouse ? Theme.fillHover : Theme.fill
                        border.width: 1
                        border.color: Theme.glassStroke
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.text
                            color: Theme.label
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotifStore.invoke(card.entry, modelData)
                        }
                    }
                }
            }
        }
    }

    // ---- Bouton × (à cheval sur le coin haut-gauche) ----
    CloseButton {
        x: -7
        y: -7
        z: 10
        visible: card.closable
        shown: card.hovered || containsMouse
        clearAll: card.clearAllMode
        onTriggered: card.closeClicked()
    }
}
