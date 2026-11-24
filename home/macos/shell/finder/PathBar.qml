import QtQuick
import qs.common

// Barre de chemin (⌥⌘P) : « Macintosh HD › Users › … › dossier », petites
// icônes de dossier, chevrons gris, éléments cliquables (double-clic ouvre),
// segments intermédiaires tronqués quand la place manque.
Item {
    id: root
    required property var fw

    // Segments : [{ name, path, isDir }]
    readonly property var segments: {
        const p = fw.path;
        if (Fs.isVirtual(p)) return [{ name: Fs.displayName(p), path: p, isDir: true }];
        const l = [{ name: Fs.rootVolumeName, path: "/", isDir: true, volume: true, volumeIcon: "drive-harddisk-system" }];
        let acc = "";
        for (const part of p.split("/").filter(x => x)) {
            acc += "/" + part;
            l.push({ name: part, path: acc, isDir: true });
        }
        const sel = fw.selection;
        if (sel.length === 1 && Fs.dirname(sel[0].path) === p) l.push(sel[0]);
        return l;
    }

    Rectangle { anchors.fill: parent; color: FStyle.contentBg }
    Rectangle { width: parent.width; height: 1; color: FStyle.gridLine }

    Row {
        id: row
        x: 12
        height: parent.height
        spacing: 0
        readonly property real avail: root.width - 24
        Repeater {
            model: root.segments
            Row {
                id: seg
                required property var modelData
                required property int index
                height: row.height
                spacing: 4
                readonly property bool last: index === root.segments.length - 1
                Symbol {
                    visible: seg.index > 0
                    name: "chevron.right"
                    size: 9
                    // Chevrons « › » bien visibles (HIG, barre de chemin de Tahoe)
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: 2; height: 1; visible: seg.index > 0 }
                FileIcon {
                    entry: seg.modelData
                    size: 14
                    thumbnails: false
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.name
                    width: Math.min(implicitWidth, seg.last ? 260 : Math.max(36, (row.avail - 160) / Math.max(1, root.segments.length - 1) - 30))
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11
                    // labelColor (≈ 85 % du noir), pas le gris secondaire
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.85)
                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: seg.modelData.isDir ? root.fw.navigate(seg.modelData.path) : Fs.open(seg.modelData.path)
                    }
                }
                Item { width: 4; height: 1 }
            }
        }
    }
}
