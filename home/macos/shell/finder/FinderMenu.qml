import QtQuick
import Quickshell
import qs.common

// Menu surgissant (xdg_popup) d'une fenêtre du Finder, avec un niveau de
// sous-menu. Le compositeur le ferme au clic extérieur (saisie du popup).
// Clavier : Haut/Bas, Entrée, Droite/Gauche (sous-menu), Échap.
Scope {
    id: root

    property var window: null
    property var items: []
    property var subItems: []
    property point pos: Qt.point(0, 0)
    property bool open: false
    // Saisie xdg_popup : exige un clic récent (faux pour l'ouverture par IPC)
    property bool grab: true

    function show(win, p, list, noGrab) {
        if (open) close();
        window = win;
        items = list;
        subItems = [];
        sub.visible = false;
        panel.highlighted = -1;
        pos = p;
        grab = !noGrab;
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() {
        open = false;
        sub.visible = false;
        subItems = [];
    }
    function run(it) {
        if (!it || it.submenu) return;
        const keep = !!it.tagToggle;
        if (!keep) close();
        if (it.action) it.action();
        if (keep) { const l = items.slice(); items = []; items = l; }
    }
    function showSub(i, rowItem) {
        const it = items[i];
        if (it && it.submenu && it.enabled !== false) {
            subItems = it.submenu;
            subPanel.highlighted = -1;
            sub.rowY = rowItem.mapToItem(panel, 0, 0).y;
            sub.anchor.updateAnchor();
            sub.visible = true;
        } else {
            sub.visible = false;
        }
    }
    function moveIn(p, list, dir) {
        const n = list.length;
        let i = p.highlighted;
        for (let k = 0; k < n; ++k) {
            i = i < 0 ? (dir > 0 ? 0 : n - 1) : (i + dir + n) % n;
            const it = list[i];
            if (it && !it.separator && !it.header && !it.tags && it.enabled !== false) { p.highlighted = i; return; }
        }
    }

    PopupWindow {
        id: popup
        visible: root.open && root.window !== null
        color: "transparent"
        grabFocus: root.grab
        anchor.window: root.window
        anchor.rect.x: root.pos.x - panel.margin
        anchor.rect.y: root.pos.y - panel.margin
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        mask: Region { item: panel.plateItem }
        onVisibleChanged: if (!visible && root.open) root.close()

        MenuPanel {
            id: panel
            anchors.fill: parent
            items: root.items
            focus: true
            onTriggered: (it) => root.run(it)
            onHoveredRow: (i, row) => root.showSub(i, row)
            Keys.onUpPressed: { sub.visible = false; root.moveIn(panel, root.items, -1); }
            Keys.onDownPressed: { sub.visible = false; root.moveIn(panel, root.items, 1); }
            Keys.onRightPressed: { const r = panel.rowItem(panel.highlighted); if (r) { root.showSub(panel.highlighted, r); subPanel.forceActiveFocus(); root.moveIn(subPanel, root.subItems, 1); } }
            Keys.onReturnPressed: root.run(root.items[panel.highlighted])
            Keys.onEnterPressed: root.run(root.items[panel.highlighted])
            Keys.onEscapePressed: root.close()
        }
    }

    PopupWindow {
        id: sub
        visible: false
        color: "transparent"
        property real rowY: 0
        anchor.window: popup
        anchor.rect.x: panel.margin + panel.contentW - subPanel.margin - 4
        anchor.rect.y: rowY - subPanel.margin - subPanel.padding
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: subPanel.implicitWidth
        implicitHeight: subPanel.implicitHeight
        mask: Region { item: subPanel.plateItem }

        MenuPanel {
            id: subPanel
            anchors.fill: parent
            items: root.subItems
            onTriggered: (it) => root.run(it)
            Keys.onUpPressed: root.moveIn(subPanel, root.subItems, -1)
            Keys.onDownPressed: root.moveIn(subPanel, root.subItems, 1)
            Keys.onLeftPressed: { sub.visible = false; panel.forceActiveFocus(); }
            Keys.onReturnPressed: root.run(root.subItems[subPanel.highlighted])
            Keys.onEscapePressed: root.close()
        }
    }
}
