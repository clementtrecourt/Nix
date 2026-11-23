import QtQuick
import QtQuick.Layouts
import qs.common

// Pile de notifications d'une application dans le Centre de notifications.
//  - 1 notification : carte simple (× = effacer).
//  - plusieurs : pile repliée (lamelles) ; clic = déplier ; × survolé = « Tout effacer ».
//  - dépliée : en-tête « Nom de l'app      [Afficher moins] (×) » puis les cartes.
Item {
    id: grp

    required property string key
    property int cardWidth: 344

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
        visible: !grp.expanded
        entry: grp.head
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

        // En-tête : nom de l'app + « Afficher moins » + ×
        Item {
            width: parent.width
            height: 28
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: grp.head ? grp.head.appName : ""
                color: Theme.label
                font.family: Theme.fontDisplay
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                // Capsule « Afficher moins »
                Item {
                    width: lessLabel.implicitWidth + 30
                    height: 24
                    Glass {
                        anchors.fill: parent
                        radius: height / 2
                        thick: true
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
                            text: "Afficher moins"
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

        // Les cartes « se déplient » depuis la tête de pile
        add: Transition {
            NumberAnimation { property: "y"; from: 36; duration: 380 * NotifStore.slow; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 * NotifStore.slow }
        }
        move: Transition {
            NumberAnimation { property: "y"; duration: 300 * NotifStore.slow; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: grp.expanded ? grp.items : []
            NotificationCard {
                required property var modelData
                width: grp.cardWidth
                entry: modelData
                onClicked: NotifStore.activate(modelData)
                onCloseClicked: NotifStore.dismiss(modelData)
            }
        }
    }
}
