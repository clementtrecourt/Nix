import QtQuick
import qs.common

// Menu déroulant « Options ⌄ » d'une notification (macOS Tahoe) : plaque de verre
// qui s'ouvre juste sous la carte, alignée sur son bord droit, avec les libellés
// complets des actions. Un seul menu par fenêtre (bannières, Centre de
// notifications) : la carte l'ouvre avec openFor(carte, entrée).
//
// Il se referme après un choix, quand la notification disparaît, ou quand le
// pointeur a quitté à la fois la carte et le menu.
Item {
    id: menu

    property var entry: null
    property Item card: null
    readonly property bool open: entry !== null
    readonly property bool hovered: menuHover.hovered

    readonly property int padV: 5
    readonly property int rowH: 24

    // Actions affichées (libellés complets) ; « Reply » (réponse en ligne) en tête
    readonly property var items: {
        if (!entry) return [];
        const l = entry.canReply ? [{ identifier: "__reply", text: "Reply", reply: true }] : [];
        return l.concat(entry.actions);
    }

    width: open ? Math.min(300, Math.max(150, menu.maxTextWidth + 2 * 15 + 10)) : 0
    height: open ? items.length * rowH + 2 * padV : 0
    visible: open || fade.running
    z: 100

    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    transformOrigin: Item.TopRight
    Behavior on opacity { NumberAnimation { id: fade; duration: Theme.durFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    function openFor(c, e) {
        if (!c || !e) return;
        card = c;
        entry = e;
        Qt.callLater(place);
    }
    // Comme sur l'image Apple (macOS 26) : bord droit ~11 pt au-delà de celui
    // de la carte, haut du menu ~4 pt AU-DESSUS du bas de la carte (le menu la
    // recouvre légèrement), sans sortir de la fenêtre.
    function place() {
        if (!card || !parent) return;
        const p = card.mapToItem(parent, card.width, card.plateHeight);
        x = Math.round(Math.max(0, Math.min(parent.width - width - 2, p.x + 11 - width)));
        y = Math.round(p.y - 4);
    }
    function close() { entry = null; card = null; }

    // Notification effacée pendant que le menu est ouvert
    Connections {
        target: NotifStore
        function onEntriesChanged() {
            if (menu.entry && !NotifStore.entries.includes(menu.entry)) menu.close();
        }
    }

    // Fermeture quand le pointeur a quitté la carte et le menu
    Timer {
        interval: 650
        running: menu.open && !menu.hovered && !(menu.card && menu.card.pointerInside)
                 && !NotifStore.debugActions
        onTriggered: menu.close()
    }

    HoverHandler { id: menuHover }

    // Largeur du plus long libellé
    FontMetrics {
        id: metrics
        font.family: Theme.font
        font.pixelSize: 13
    }
    readonly property real maxTextWidth: {
        let m = 0;
        for (const it of items) m = Math.max(m, metrics.advanceWidth(it.text));
        return Math.ceil(m);
    }

    NotifGlass {
        anchors.fill: parent
        radius: Theme.radiusMenu
        tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.80) : Qt.rgba(0.97, 0.97, 0.98, 0.80)
        shadowOffset: 6
        shadowBlur: 0.8
    }

    Column {
        x: 5
        y: menu.padV
        width: menu.width - 10
        Repeater {
            model: menu.items
            Item {
                id: row
                required property var modelData
                width: parent.width
                height: menu.rowH
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMenuItem
                    color: Theme.menuHighlight
                    visible: rowMouse.containsMouse
                }
                Text {
                    x: 10
                    width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text
                    color: rowMouse.containsMouse ? Theme.menuHighlightText : Theme.label
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const e = menu.entry;
                        const c = menu.card;
                        menu.close();
                        if (row.modelData.reply) { if (c) c.startReply(); }
                        else NotifStore.invoke(e, row.modelData);
                    }
                }
            }
        }
    }
}
