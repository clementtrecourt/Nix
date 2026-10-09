import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    signal done()

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // --- historique d'usage : les apps lancées souvent remontent ---
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/state/quickshell/launcher.json"
        blockLoading: true
        onLoadFailed: writeAdapter()
        JsonAdapter {
            id: usage
            property string counts: "{}"
        }
    }

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property string query: input.text.trim().toLowerCase()

    function score(e, q, counts) {
        const name = e.name.toLowerCase()
        let s = 0
        if (name === q) s = 1000
        else if (name.startsWith(q)) s = 800
        else if (name.split(/[\s\-_]+/).some(w => w.startsWith(q))) s = 600
        else if (name.includes(q)) s = 400
        else if ((e.genericName || "").toLowerCase().includes(q)) s = 200
        else if ((e.keywords || []).some(k => k.toLowerCase().includes(q))) s = 150
        else if ((e.comment || "").toLowerCase().includes(q)) s = 80
        else return -1
        return s + Math.min(counts[e.id] || 0, 50)
    }

    readonly property var results: {
        let counts = {}
        try { counts = JSON.parse(usage.counts) } catch (e) {}
        const q = query
        if (q === "")
            return [...apps].sort((a, b) => (counts[b.id] || 0) - (counts[a.id] || 0)
                                          || a.name.localeCompare(b.name)).slice(0, 50)
        return apps
            .map(e => ({ e: e, s: score(e, q, counts) }))
            .filter(x => x.s >= 0)
            .sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name))
            .slice(0, 50)
            .map(x => x.e)
    }
    onResultsChanged: list.currentIndex = 0

    function launch(i) {
        const e = results[i]
        if (!e) return
        try {
            const counts = JSON.parse(usage.counts)
            counts[e.id] = (counts[e.id] || 0) + 1
            usage.counts = JSON.stringify(counts)
            store.writeAdapter()
        } catch (err) {}

        if (e.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(e.command))
        else e.execute()
        done()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.done()
    }

    Rectangle {
        id: panel
        readonly property int rowH: 44

        anchors.centerIn: parent
        width: Math.min(Config.launcherWidth, parent.width * 0.9)
        height: 14 * 2 + 40 + 10 + Math.min(Config.launcherRows, Math.max(1, list.count)) * rowH
        radius: 14
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.95)
        border.width: 1
        border.color: Colors.outline

        // absorbe les clics pour ne pas fermer
        MouseArea { anchors.fill: parent }

        Column {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            Rectangle {
                width: parent.width
                height: 40
                radius: 8
                color: Colors.surfaceContainer

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.text
                    selectionColor: Colors.primary
                    clip: true
                    focus: true
                    font { family: Config.font; pixelSize: 15 }
                    Component.onCompleted: forceActiveFocus()

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Lancer une application…"
                        color: Colors.textMuted
                        font: input.font
                    }

                    Keys.onPressed: event => {
                        const k = event.key
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (k === Qt.Key_Escape) root.done()
                        else if (k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && (k === Qt.Key_N || k === Qt.Key_J))) list.incrementCurrentIndex()
                        else if (k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && (k === Qt.Key_P || k === Qt.Key_K))) list.decrementCurrentIndex()
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.launch(list.currentIndex)
                        else return
                        event.accepted = true
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 50
                clip: true
                model: root.results
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem

                    width: list.width
                    height: panel.rowH
                    radius: 8
                    color: current ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25) : "transparent"

                    Image {
                        id: icon
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 28
                        height: 28
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        sourceSize: Qt.size(56, 56)
                        asynchronous: true
                    }

                    Column {
                        anchors { left: icon.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.modelData.name
                            color: Colors.text
                            elide: Text.ElideRight
                            font { family: Config.font; pixelSize: 14; weight: row.current ? Font.DemiBold : Font.Normal }
                        }
                        Text {
                            visible: text !== ""
                            width: parent.width
                            text: row.modelData.genericName || row.modelData.comment || ""
                            color: Colors.textMuted
                            elide: Text.ElideRight
                            font { family: Config.font; pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: { list.currentIndex = row.index; root.launch(row.index) }
                    }
                }
            }
        }
    }
}
