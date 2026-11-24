import QtQuick
import qs.common

// « Go to Folder » (⇧⌘G) : champ flottant en haut de la fenêtre (macOS 13+),
// icône de dossier, chemin saisi, suggestions complétées au fil de la frappe
// (Tab complète, ↑/↓ choisissent), Entrée ouvre, Échap ferme.
Item {
    id: root

    required property var fw
    anchors.fill: parent
    visible: fw.showGoTo

    property string text: ""
    property int current: -1
    readonly property string typed: text.startsWith("~") ? Fs.home + text.slice(1) : text
    readonly property string baseDir: typed.endsWith("/") ? (typed.length > 1 ? typed.slice(0, -1) : "/") : Fs.dirname(typed)
    readonly property string prefix: typed.endsWith("/") ? "" : Fs.basename(typed)
    readonly property var suggestions: typed.startsWith("/") && sugg.ok
        ? sugg.entries.filter(e => e.isDir && !e.hidden && e.name.toLowerCase().startsWith(prefix.toLowerCase()))
              .sort((a, b) => a.name.localeCompare(b.name)).slice(0, 8)
        : []

    onVisibleChanged: if (visible) {
        text = fw.isVirtual ? "~/" : fw.path.replace(Fs.home, "~") + "/";
        current = -1;
        input.forceActiveFocus();
        input.selectAll();
    }

    DirLister {
        id: sugg
        watch: false
        path: root.visible && root.typed.startsWith("/") ? root.baseDir : ""
    }

    function go(p) {
        let t = (p ?? typed).trim();
        if (!t) return;
        if (t.startsWith("~")) t = Fs.home + t.slice(1);
        fw.showGoTo = false;
        fw.focusStage();
        if (!t.startsWith("/")) t = Fs.join(fw.isVirtual ? Fs.home : fw.path, t);
        fw.finder.openInWindow(fw, t);
    }

    // Clic hors du champ : ferme
    MouseArea {
        anchors.fill: parent
        onPressed: { root.fw.showGoTo = false; root.fw.focusStage(); }
    }

    Item {
        id: panel
        width: Math.min(560, parent.width - 80)
        height: 52 + (root.suggestions.length ? root.suggestions.length * 28 + 10 : 0)
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64
        MouseArea { anchors.fill: parent }

        Glass {
            anchors.fill: parent
            radius: 14
            tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.97) : Qt.rgba(0.985, 0.985, 0.99, 0.98)
            shadowBlur: 1.0
            shadowOffset: 10
            shadowMax: 1.0
            shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.5 : 0.22)
            glowWidth: 0
        }
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.width: 0.5
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        }
        Symbol {
            x: 16
            y: 15
            name: "folder"
            size: 22
            color: Theme.accent
        }
        TextInput {
            id: input
            x: 50
            y: 14
            width: parent.width - 66
            text: root.text
            onTextEdited: { root.text = text; root.current = -1; }
            font.family: Theme.font
            font.pixelSize: 18
            color: Theme.label
            selectionColor: Theme.accent
            selectedTextColor: "white"
            clip: true
            Keys.onReturnPressed: root.go(root.current >= 0 ? root.suggestions[root.current].path : undefined)
            Keys.onEnterPressed: root.go(root.current >= 0 ? root.suggestions[root.current].path : undefined)
            Keys.onEscapePressed: { root.fw.showGoTo = false; root.fw.focusStage(); }
            Keys.onDownPressed: root.current = Math.min(root.suggestions.length - 1, root.current + 1)
            Keys.onUpPressed: root.current = Math.max(-1, root.current - 1)
            Keys.onTabPressed: {
                const s = root.current >= 0 ? root.suggestions[root.current] : root.suggestions[0];
                if (s) { root.text = s.path.replace(Fs.home, "~") + "/"; root.current = -1; }
            }
        }
        Rectangle {
            visible: root.suggestions.length > 0
            y: 51
            x: 12
            width: parent.width - 24
            height: 1
            color: FStyle.gridLine
        }
        Column {
            x: 6
            y: 57
            width: parent.width - 12
            Repeater {
                model: root.suggestions
                Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 28
                    radius: 6
                    color: root.current === index ? Theme.accent : "transparent"
                    FileIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; size: 18; entry: parent.modelData; thumbnails: false }
                    Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.path.replace(Fs.home, "~")
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: root.current === parent.index ? "white" : Theme.label
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.current = parent.index
                        onClicked: root.go(parent.modelData.path)
                    }
                }
            }
        }
    }
}
