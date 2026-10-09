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
    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var entries: []
    readonly property string query: input.text.trim().toLowerCase()
    readonly property var filtered: query === ""
        ? entries
        : entries.filter(e => e.text.toLowerCase().includes(query))
    onFilteredChanged: list.currentIndex = 0

    // "123<TAB>texte" -> { id, text }
    Process {
        running: true
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.length > 0).map(l => {
                    const i = l.indexOf("\t")
                    return { id: l.slice(0, i), text: l.slice(i + 1) }
                })
            }
        }
    }

    function pick(i) {
        const e = filtered[i]
        if (!e) return
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", e.id])
        done()
    }

    function remove(i) {
        const e = filtered[i]
        if (!e) return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", e.id])
        entries = entries.filter(x => x.id !== e.id)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.done()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(720, parent.width * 0.9)
        height: Math.min(520, parent.height * 0.7)
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
                        text: "Rechercher…"
                        color: Colors.textMuted
                        font: input.font
                    }

                    Keys.onPressed: event => {
                        const k = event.key
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (k === Qt.Key_Escape) root.done()
                        else if (k === Qt.Key_Down || (ctrl && (k === Qt.Key_N || k === Qt.Key_J))) list.incrementCurrentIndex()
                        else if (k === Qt.Key_Up || (ctrl && (k === Qt.Key_P || k === Qt.Key_K))) list.decrementCurrentIndex()
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.pick(list.currentIndex)
                        else if (ctrl && k === Qt.Key_D) root.remove(list.currentIndex)
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
                model: root.filtered
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem

                    width: list.width
                    height: 34
                    radius: 6
                    color: current ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25) : "transparent"

                    Text {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.text
                        color: row.current ? Colors.text : Colors.textMuted
                        elide: Text.ElideRight
                        font { family: Config.font; pixelSize: 13 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: { list.currentIndex = row.index; root.pick(row.index) }
                    }
                }
            }
        }
    }
}
