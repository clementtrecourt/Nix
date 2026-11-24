import QtQuick
import qs.common

// Présentation Galerie : grand aperçu de l'élément choisi, bande de vignettes
// en bas (pastille grise derrière la vignette choisie), volet d'informations
// à droite (capture Apple mchldaafb302, « Gallery view »).
Item {
    id: root

    required property var fw
    readonly property var entries: fw.items
    readonly property real paneW: width > 700 ? 300 : 0
    readonly property real stripH: 78
    readonly property var current: fw.selection.length ? fw.selection[fw.selection.length - 1] : null

    function indexOf(p) { return entries.findIndex(e => e.path === p); }
    function ensureVisible(p) {
        const i = indexOf(p);
        if (i >= 0) strip.positionViewAtIndex(i, ListView.Contain);
    }
    function navigate(k, extend) {
        const n = entries.length;
        if (!n) return;
        let i = indexOf(fw.cursorPath);
        if (k === Qt.Key_Left || k === Qt.Key_Up) i = i < 0 ? 0 : Math.max(0, i - 1);
        else if (k === Qt.Key_Right || k === Qt.Key_Down) i = i < 0 ? 0 : Math.min(n - 1, i + 1);
        else if (k === Qt.Key_Home) i = 0;
        else if (k === Qt.Key_End) i = n - 1;
        else return;
        if (extend) fw.clickItem(entries[i], Qt.ShiftModifier, entries);
        else fw.selectPaths([entries[i].path]);
    }
    // La Galerie montre toujours un élément : le premier par défaut
    function autoSelect() { if (!fw.selection.length && entries.length) fw.selectPaths([entries[0].path]); }
    onEntriesChanged: Qt.callLater(autoSelect)
    Component.onCompleted: Qt.callLater(autoSelect)

    // ---- Grand aperçu ----
    Item {
        id: stageArea
        x: 0
        y: fw.chromeHeight + 10
        width: parent.width - root.paneW
        height: parent.height - y - root.stripH - 6
        FileIcon {
            id: big
            anchors.centerIn: parent
            size: Math.min(parent.width - 60, parent.height - 10)
            entry: root.current
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: (m) => {
                root.fw.focusStage();
                if (m.button === Qt.RightButton && root.current) root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
            }
            onDoubleClicked: if (root.current) root.fw.openEntry(root.current)
        }
    }

    // ---- Bande de vignettes ----
    ListView {
        id: strip
        x: 0
        y: parent.height - root.stripH
        width: parent.width - root.paneW
        height: root.stripH
        orientation: ListView.Horizontal
        leftMargin: 10
        rightMargin: 10
        spacing: 4
        model: root.entries
        acceptedButtons: Qt.NoButton
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        clip: true

        delegate: Item {
            id: th
            required property var modelData
            readonly property bool sel: root.fw.isSel(modelData.path)
            width: 56
            height: strip.height
            Rectangle {
                anchors.centerIn: parent
                width: 56
                height: 62
                radius: 7
                color: th.sel ? (root.fw.active ? FStyle.selectionIcon : FStyle.selectionInactive) : "transparent"
                border.width: th.sel ? 0 : 0
            }
            FileIcon {
                id: ti
                anchors.centerIn: parent
                size: 44
                entry: th.modelData
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point pressPos
                property bool dragged: false
                onPressed: (m) => {
                    pressPos = Qt.point(m.x, m.y);
                    dragged = false;
                    root.fw.clickItem(th.modelData, m.modifiers, root.entries);
                    if (m.button === Qt.RightButton) root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                }
                onPositionChanged: (m) => {
                    if (pressed && !dragged && (m.buttons & Qt.LeftButton) && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > 5) {
                        dragged = true;
                        root.fw.beginDrag(ti);
                    }
                }
                onReleased: (m) => { if (!dragged && !(m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier))) root.fw.selectPaths([th.modelData.path]); }
                onDoubleClicked: root.fw.openEntry(th.modelData)
            }
        }
    }
    OverlayScrollbar {
        flick: strip
        horizontal: true
        x: strip.x
        width: strip.width
        anchors.bottom: parent.bottom
    }

    // ---- Volet d'informations ----
    Item {
        visible: root.paneW > 0
        x: parent.width - root.paneW
        width: root.paneW
        height: parent.height
        Rectangle {
            x: 0
            y: fw.chromeHeight
            width: 1
            height: parent.height - y
            color: FStyle.gridLine
        }
        PreviewPane {
            anchors.fill: parent
            anchors.topMargin: fw.chromeHeight + 16
            entry: root.current
            compact: false
        }
    }
}
