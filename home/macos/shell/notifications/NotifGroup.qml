import QtQuick
import QtQuick.Layouts
import qs.common

// Pile de notifications d'une application dans le Centre de notifications.
//  - 1 notification : carte simple (× = effacer).
//  - plusieurs : pile repliée (lamelles) ; clic = déplier ; × survolé = « Clear All ».
//  - dépliée : en-tête « Nom de l'app      [Show less] (×) » puis les cartes.
Item {
    id: grp

    required property string key
    property int cardWidth: 344
    property Item menuHost: null

    readonly property var items: { NotifStore.entries; return NotifStore.groupItems(key); }
    readonly property bool expanded: NotifStore.isExpanded(key) && items.length > 1
    // Dernière tête connue : reste affichée pendant l'animation de suppression
    property var head: null
    onItemsChanged: if (items.length) head = items[0]

    width: cardWidth
    implicitHeight: expanded ? expandedCol.implicitHeight : collapsedCard.implicitHeight
    Behavior on implicitHeight { NumberAnimation { duration: 320 * NotifStore.slow; easing.type: Easing.OutCubic } }

    // ---- Repliée ----
    NotificationCard {
        id: collapsedCard
        width: grp.cardWidth
        // Fondu (pas de disparition sèche) pendant que les cartes se déploient
        opacity: grp.expanded ? 0 : 1
        visible: opacity > 0
        enabled: !grp.expanded
        interactive: !grp.expanded
        Behavior on opacity { NumberAnimation { duration: 140 * NotifStore.slow } }
        entry: grp.head
        menuHost: grp.menuHost
        stackCount: grp.items.length
        clearAllMode: grp.items.length > 1
        onClicked: {
            if (grp.items.length > 1) NotifStore.setExpanded(grp.key, true);
            else if (entry) NotifStore.activate(entry);
        }
        onCloseClicked: {
            if (grp.items.length > 1) NotifStore.clearGroup(grp.key);
            else if (entry) NotifStore.dismiss(entry);
        }
    }

    // ---- Dépliée ----
    Column {
        id: expandedCol
        width: grp.cardWidth
        visible: grp.expanded
        spacing: 8

        // En-tête : nom de l'app + « Show less » + ×
        Item {
            width: parent.width
            height: 28
            opacity: grp.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 260 * NotifStore.slow; easing.type: Easing.OutCubic } }
            // Nom de l'app, tronqué « … » avant les boutons (y compris quand le ×
            // s'allonge en « Clear All » au survol)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 4 - headerButtons.width - 10
                elide: Text.ElideRight
                maximumLineCount: 1
                text: grp.head ? grp.head.appName : ""
                color: Theme.label
                font.family: Theme.fontDisplay
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Row {
                id: headerButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                // Capsule « Show less »
                Item {
                    id: lessBtn
                    width: lessLabel.implicitWidth + 30
                    height: 24
                    NotifGlass {
                        anchors.fill: parent
                        radius: height / 2
                        tint: Theme.dark ? Qt.rgba(0.20, 0.20, 0.21, 0.72) : Qt.rgba(0.97, 0.97, 0.98, 0.80)
                        shadowOffset: 2
                        shadowBlur: 0.5
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Symbol {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron.up"
                            size: 9
                            color: Theme.label
                        }
                        Text {
                            id: lessLabel
                            anchors.verticalCenter: parent.verticalCenter
                            // Libellé exact de l'aide Apple (macOS 26) : « Show less »
                            text: "Show less"
                            color: Theme.label
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifStore.setExpanded(grp.key, false)
                    }
                }
                CloseButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    shown: true
                    clearAll: true
                    onTriggered: NotifStore.clearGroup(grp.key)
                }
            }
        }

        // Les cartes « se déplient » depuis la pile repliée : chacune part de la
        // position de sa lamelle (tête en haut, les suivantes 9 pt plus bas,
        // légèrement réduites) et glisse vers sa place.
        add: Transition {
            NumberAnimation {
                property: "y"
                from: Math.min(Math.max(ViewTransition.index - 1, 0), 2) * 9
                duration: 420 * NotifStore.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.9, 0.25, 1.0, 1, 1]
            }
            NumberAnimation {
                property: "scale"
                from: ViewTransition.index <= 1 ? 1 : 0.93
                to: 1
                duration: 420 * NotifStore.slow
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: ViewTransition.index <= 1 ? 1 : 0.6
                to: 1
                duration: 300 * NotifStore.slow
            }
        }
        move: Transition {
            NumberAnimation { property: "y"; duration: 300 * NotifStore.slow; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: grp.expanded ? grp.items : []
            NotificationCard {
                required property var modelData
                required property int index
                z: -index            // la tête reste au-dessus pendant le déploiement
                width: grp.cardWidth
                entry: modelData
                menuHost: grp.menuHost
                onClicked: NotifStore.activate(modelData)
                onCloseClicked: NotifStore.dismiss(modelData)
            }
        }
    }
}
