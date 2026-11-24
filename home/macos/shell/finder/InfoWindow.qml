import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// « Get Info » (⌘I) : petite fenêtre « <nom> Info » de macOS. En-tête (icône,
// nom en gras, taille, « Modified: Today, 9:41 AM »), champ de tags, puis
// sections repliables : General, More Info, Name & Extension, Comments,
// Open with, Preview, Sharing & Permissions (capture Apple mchlp2313).
FloatingWindow {
    id: win

    required property var entry
    signal dismissed()

    title: Fs.displayName(entry.path) + " Info"
    color: Theme.dark ? "#262628" : "#F2F2F4"
    implicitWidth: 300
    implicitHeight: Math.min(720, body.implicitHeight + 40)
    minimumSize: Qt.size(260, 200)
    onVisibleChanged: if (!visible) win.dismissed()

    property var open: ({ general: true, more: true, name: false, comments: false, openwith: false, preview: true, sharing: false })
    function toggle(k) { const o = Object.assign({}, open); o[k] = !o[k]; open = o; }

    // Taille réelle (dossiers : du), nombre d'éléments, propriétaire, droits
    property var stat: ({})
    ProcessCollector {
        id: statProc
        running: true
        command: ["sh", "-c", `
            p="$1"
            echo "bytes=$(du -sb -- "$p" 2>/dev/null | cut -f1)"
            echo "disk=$(du -sB1 -- "$p" 2>/dev/null | cut -f1)"
            [ -d "$p" ] && echo "count=$(find "$p" -mindepth 1 2>/dev/null | wc -l)"
            echo "owner=$(stat -c %U -- "$p" 2>/dev/null)"
            echo "group=$(stat -c %G -- "$p" 2>/dev/null)"
            echo "mode=$(stat -c %A -- "$p" 2>/dev/null)"
            echo "birth=$(stat -c %W -- "$p" 2>/dev/null)"
            echo "mtime=$(stat -c %Y -- "$p" 2>/dev/null)"
            echo "atime=$(stat -c %X -- "$p" 2>/dev/null)"
            [ -w "$p" ] && echo "w=1"
        `, "sh", win.entry.path]
        onDone: (t) => {
            const o = {};
            for (const l of t.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); }
            win.stat = o;
        }
    }
    readonly property real mtime: Number(stat.mtime) || entry.mtime || 0
    readonly property real btime: (Number(stat.birth) > 0 ? Number(stat.birth) : 0) || entry.btime || mtime
    // « Today, 9:41 AM » (forme de l'en-tête de Get Info)
    function shortDate(secs) {
        const f = Fs.formatDate(secs);
        return f.replace(" at ", ", ");
    }
    readonly property string sizeText: {
        const b = Number(stat.bytes);
        if (entry.app) return "--";
        if (!stat.bytes) return "";
        return Fs.formatSize(b);
    }
    readonly property string sizeLong: {
        const b = Number(stat.bytes), d = Number(stat.disk);
        if (!stat.bytes) return "Calculating…";
        let s = Fs.formatBytes(b) + " (" + Fs.formatSize(d) + " on disk)";
        if (entry.isDir && stat.count !== undefined) s += " for " + Fs.itemsLabel(Number(stat.count));
        return s;
    }
    readonly property string where: {
        const d = Fs.dirname(entry.path);
        const parts = d.split("/").filter(x => x);
        return [Fs.rootVolumeName].concat(parts).join(" › ");
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if ((e.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && e.key === Qt.Key_W) { win.dismissed(); e.accepted = true; }
            if (e.key === Qt.Key_Escape) { win.dismissed(); e.accepted = true; }
        }

        // ---- Barre de titre ----
        Item {
            id: titleBar
            width: parent.width
            height: 32
            MouseArea { anchors.fill: parent; onPressed: win.startSystemMove() }
            TrafficLights {
                x: 12
                y: 9
                size: 12
                spacing: 8
                active: true
                onCloseClicked: win.dismissed()
            }
            Row {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 20
                spacing: 5
                FileIcon { size: 16; entry: win.entry; thumbnails: false; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, win.width - 120)
                    elide: Text.ElideMiddle
                    text: win.title
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(0, 0, 0, 0.70)
                }
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.topMargin: titleBar.height
            contentHeight: body.implicitHeight + 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 0

                // ---- En-tête ----
                Item {
                    width: body.width
                    height: 52
                    FileIcon { x: 12; y: 4; size: 40; entry: win.entry }
                    Text {
                        x: 60
                        y: 7
                        width: parent.width - x - sizeT.implicitWidth - 20
                        elide: Text.ElideMiddle
                        text: Fs.displayName(win.entry.path)
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.label
                    }
                    Text {
                        id: sizeT
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        y: 7
                        text: win.sizeText
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.label
                    }
                    Text {
                        x: 60
                        y: 26
                        text: win.mtime ? "Modified: " + win.shortDate(win.mtime) : ""
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: FStyle.secondaryText
                    }
                }
                // ---- Tags ----
                Rectangle {
                    x: 10
                    width: body.width - 20
                    height: 34
                    color: FStyle.contentBg
                    border.width: 1
                    border.color: FStyle.gridLine
                    Row {
                        x: 6; y: 8; spacing: 4
                        Repeater {
                            model: Fs.tagsOf(win.entry.path)
                            Rectangle {
                                required property string modelData
                                height: 18; width: tl.implicitWidth + 22; radius: 9
                                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
                                Rectangle { x: 5; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Fs.tagColor(parent.modelData) }
                                Text { id: tl; x: 16; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData; font.family: Theme.font; font.pixelSize: 11; color: Theme.label }
                            }
                        }
                    }
                    Text {
                        visible: Fs.tagsOf(win.entry.path).length === 0
                        x: 6; y: 6
                        text: "Add Tags…"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.labelTertiary
                    }
                }
                Item { width: 1; height: 8 }

                // ---- Sections ----
                Section {
                    key: "general"
                    title: "General:"
                    Field { label: "Kind:"; value: Fs.kindOf(win.entry) }
                    Field { label: "Size:"; value: win.sizeLong }
                    Field { label: "Where:"; value: win.where }
                    Field { label: "Created:"; value: Fs.formatDateLong(win.btime) }
                    Field { label: "Modified:"; value: Fs.formatDateLong(win.mtime) }
                    Item { width: 1; height: 4 }
                    Check { visible: !win.entry.isDir; label: "Stationery pad" }
                    Check { visible: win.entry.isDir; label: "Shared folder" }
                    Check { label: "Locked"; checked: win.stat.w === undefined && win.stat.mode !== undefined }
                }
                Section {
                    key: "more"
                    title: "More Info:"
                    Field { label: "Last opened:"; value: Fs.formatDateLong(Number(win.stat.atime) || win.entry.atime || win.mtime) }
                    Field { visible: dimProbe.status === Image.Ready; label: "Dimensions:"; value: dimProbe.implicitWidth + " × " + dimProbe.implicitHeight }
                }
                Section {
                    key: "name"
                    title: "Name & Extension:"
                    Rectangle {
                        width: parent.width
                        height: 22
                        color: FStyle.contentBg
                        border.width: 1
                        border.color: FStyle.gridLine
                        TextInput {
                            id: nameField
                            x: 4
                            width: parent.width - 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.entry.name
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.label
                            clip: true
                            selectByMouse: true
                            readOnly: Fs.isVirtual(win.entry.path) || !!win.entry.app
                            onAccepted: {
                                const n = text.replace(/\//g, ":").trim();
                                if (n && n !== win.entry.name) Fs.rename(win.entry.path, Fs.join(Fs.dirname(win.entry.path), n));
                            }
                        }
                    }
                    Check { label: "Hide extension"; visible: !win.entry.isDir }
                }
                Section {
                    key: "comments"
                    title: "Comments:"
                    Rectangle { width: parent.width; height: 44; color: FStyle.contentBg; border.width: 1; border.color: FStyle.gridLine }
                }
                Section {
                    key: "openwith"
                    title: "Open with:"
                    visible: !win.entry.isDir && !win.entry.app
                    Text { text: "Use this application to open all documents like this one."; wrapMode: Text.Wrap; width: parent.width; font.family: Theme.font; font.pixelSize: 11; color: Theme.label }
                }
                Section {
                    key: "preview"
                    title: "Preview:"
                    Item {
                        width: parent.width
                        height: 140
                        FileIcon { anchors.centerIn: parent; size: 128; entry: win.entry }
                    }
                }
                Section {
                    key: "sharing"
                    title: "Sharing & Permissions:"
                    Text {
                        text: win.stat.w ? "You can read and write" : "You can only read"
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.label
                    }
                    Repeater {
                        model: [[(win.stat.owner ?? Fs.user) + " (Me)", win.perm(1)], [win.stat.group ?? "staff", win.perm(4)], ["everyone", win.perm(7)]]
                        Row {
                            required property var modelData
                            width: parent.width
                            Text { width: parent.width * 0.6; text: parent.modelData[0]; font.family: Theme.font; font.pixelSize: 11; color: Theme.label; elide: Text.ElideRight }
                            Text { text: parent.modelData[1]; font.family: Theme.font; font.pixelSize: 11; color: Theme.label }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: FStyle.gridLine }
            }
        }
    }
    component Section: Column {
        id: sec
        property string key
        property string title
        default property alias content: inner.data
        width: body.width
        Rectangle { width: parent.width; height: 1; color: FStyle.gridLine }
        Item {
            width: parent.width
            height: 24
            Symbol {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron.right"
                size: 9
                rotation: win.open[sec.key] ? 90 : 0
                color: FStyle.secondaryText
                Behavior on rotation { NumberAnimation { duration: 120 } }
            }
            Text {
                x: 28
                anchors.verticalCenter: parent.verticalCenter
                text: sec.title
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.label
            }
            MouseArea { anchors.fill: parent; onClicked: win.toggle(sec.key) }
        }
        Column {
            id: inner
            visible: !!win.open[sec.key]
            x: 28
            width: parent.width - 40
            spacing: 3
            bottomPadding: 8
        }
    }
    component Field: Row {
        property string label
        property string value
        spacing: 4
        width: parent?.width ?? 200
        Text {
            id: fl
            text: parent.label
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Theme.label
        }
        Text {
            width: parent.width - fl.implicitWidth - 4
            text: parent.value
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.label
        }
    }
    component Check: Row {
        property string label
        property bool checked: false
        spacing: 6
        Rectangle {
            width: 14; height: 14; radius: 4
            color: parent.checked ? Theme.accent : FStyle.contentBg
            border.width: parent.checked ? 0 : 1
            border.color: FStyle.gridLine
            Symbol { visible: parent.parent.checked; anchors.centerIn: parent; name: "checkmark"; size: 9; color: "white" }
        }
        Text { text: parent.label; font.family: Theme.font; font.pixelSize: 11; color: Theme.label }
    }


    // Droits Unix -> libellés macOS (« Read & Write », « Read only », « No Access »)
    function perm(i) {
        const m = stat.mode ?? "";
        if (m.length < 10) return "";
        const r = m[i] === "r", w = m[i + 1] === "w";
        return r && w ? "Read & Write" : r ? "Read only" : w ? "Write only (Drop Box)" : "No Access";
    }
    Image {
        id: dimProbe
        visible: false
        asynchronous: true
        source: Fs.isImage(win.entry) && Fs.ext(win.entry.name) !== "svg" ? Fs.fileUrl(win.entry.path) : ""
    }
}
