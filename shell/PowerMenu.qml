import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    signal done()

    anchors { top: true; bottom: true; left: true; right: true }
    color: Qt.rgba(0, 0, 0, Config.overlayDim)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-power"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var actions: [
        { label: "Verrouiller", icon: "\uf023", key: Qt.Key_L, hint: "l", confirm: false,
          cmd: Config.lockCmd() },
        { label: "Quitter", icon: "\uf08b", key: Qt.Key_E, hint: "e", confirm: true,
          cmd: ["mmsg", "dispatch", "quit"] },
                { label: "Veille", icon: "\uf186", key: Qt.Key_S, hint: "s", confirm: false,
          cmd: ["sh", "-c", "(" + Config.lockSh + ") & sleep 0.5; systemctl suspend"] },
        { label: "Redémarrer", icon: "\uf021", key: Qt.Key_R, hint: "r", confirm: true,
          cmd: ["systemctl", "reboot"] },
        { label: "Éteindre", icon: "\uf011", key: Qt.Key_P, hint: "p", confirm: true,
          cmd: ["systemctl", "poweroff"] }
    ]

    property int current: 0

    function run(i) {
        Quickshell.execDetached(actions[i].cmd)
        done()
    }

    // lettre / clic : les actions destructives demandent une 2e pression
    function trigger(i) {
        if (actions[i].confirm && current !== i) current = i
        else run(i)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.done()
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape || k === Qt.Key_Q) { root.done(); event.accepted = true; return }
            if (k === Qt.Key_Left) root.current = (root.current + root.actions.length - 1) % root.actions.length
            else if (k === Qt.Key_Right || k === Qt.Key_Tab) root.current = (root.current + 1) % root.actions.length
            else if (k === Qt.Key_Backtab) root.current = (root.current + root.actions.length - 1) % root.actions.length
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.run(root.current)
            else if (k >= Qt.Key_1 && k < Qt.Key_1 + root.actions.length) root.trigger(k - Qt.Key_1)
            else {
                const i = root.actions.findIndex(a => a.key === k)
                if (i < 0) return
                root.trigger(i)
            }
            event.accepted = true
        }

        Column {
            anchors.centerIn: parent
            spacing: 28

            Row {
                id: row
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool sel: root.current === index
                        readonly property color accent: modelData.confirm ? Colors.error : Colors.primary

                        width: 150
                        height: 150
                        radius: 16
                        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, sel ? 0.95 : 0.75)
                        border.width: sel ? 3 : 0
                        border.color: accent
                        scale: sel ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.icon
                                color: tile.sel ? tile.accent : Colors.text
                                font { family: Config.iconFont; pixelSize: 44 }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: Colors.text
                                font { family: Config.font; pixelSize: 15; weight: Font.Medium }
                            }
                        }

                        Text {
                            anchors { top: parent.top; right: parent.right; margins: 10 }
                            text: tile.modelData.hint
                            color: Colors.textMuted
                            font { family: Config.font; pixelSize: 12 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.current = tile.index
                            onClicked: root.trigger(tile.index)
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var a: root.actions[root.current]
                text: a.confirm ? "Entrée ou « " + a.hint + " » pour confirmer" : ""
                color: Colors.error
                font { family: Config.font; pixelSize: 14 }
            }
        }
    }
}
