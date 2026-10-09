import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root
    required property bool vertical
    required property string screenName

    property var tags: []
    readonly property var shown: tags.filter(t =>
        !Config.wsHideEmpty || t.is_active || t.is_urgent || t.client_count > 0)

    columns: vertical ? 1 : 100
    rowSpacing: 6
    columnSpacing: 6

    // un flux d'événements par écran, pas de polling
    Process {
        id: watcher
        running: root.screenName !== ""
        command: ["mmsg", "watch", "tags", root.screenName]
        stdout: SplitParser {
            onRead: data => {
                try { root.tags = JSON.parse(data).tags } catch (e) {}
            }
        }
        // si mango redémarre, on se reconnecte
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: watcher.running = true
    }

    Repeater {
        model: root.shown

        Rectangle {
            id: ws
            required property var modelData
            readonly property bool active: modelData.is_active
            readonly property bool urgent: modelData.is_urgent
            readonly property bool occupied: modelData.client_count > 0

            Layout.preferredWidth: Config.wsSize
            Layout.preferredHeight: Config.wsSize
            radius: Config.wsSize / 2
            color: urgent ? Colors.error
                 : active ? Colors.primary
                 : occupied ? Colors.surfaceContainer
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: ws.modelData.index
                color: ws.urgent || ws.active ? Colors.primaryText
                     : ws.occupied ? Colors.text : Colors.textMuted
                font { family: Config.font; pixelSize: 12; weight: ws.active ? Font.Bold : Font.Normal }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached(["mmsg", "dispatch", "view," + ws.modelData.index])
            }
        }
    }
}
