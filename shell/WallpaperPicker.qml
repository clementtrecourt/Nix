import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    signal done()

    // plein écran : sert de fond assombri et capte le clavier
    anchors { top: true; bottom: true; left: true; right: true }
    color: Qt.rgba(0, 0, 0, Config.pickerDim)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var files: []

    function choose(i) {
        if (i < 0 || i >= files.length) return
        Quickshell.execDetached(["set-wallpaper", files[i]])
        done()
    }

    Process {
        running: true
        command: ["fd", "-t", "f", "-a", "-e", "jpg", "-e", "jpeg", "-e", "png", "-e", "webp", ".", Config.wallpaperDir]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(l => l.length > 0).sort()
        }
    }

    Item {
        id: content
        anchors.fill: parent

        // clic dans le vide = fermer
        MouseArea {
            anchors.fill: parent
            onClicked: root.done()
        }

        ListView {
            id: list

            // --- dimensionnement adaptatif ---
            readonly property real tileH: Math.min(Config.pickerHeight, content.height * 0.6)
            readonly property real pad: Math.abs(Config.pickerSkew) * tileH / 2   // débord de l'inclinaison
            readonly property int visibleCount: Math.max(2, Math.min(
                Config.pickerCount,
                Math.floor(width / (tileH * Config.pickerMinAspect))))
            readonly property real tileW: (width - 2 * pad) / visibleCount - spacing

            anchors.centerIn: parent
            width: content.width * Config.pickerWidthRatio
            height: tileH
            leftMargin: pad
            rightMargin: pad
            spacing: 4
            orientation: ListView.Horizontal
            clip: true
            cacheBuffer: width * 2
            model: root.files
            focus: true

            Component.onCompleted: forceActiveFocus()

            // défile seulement quand la sélection sort de la vue
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            Behavior on contentX { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        // molette / touchpad : déplace la sélection (comme h / l)
            WheelHandler {
                property real acc: 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    acc += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    while (acc >= 120) { list.decrementCurrentIndex(); acc -= 120 }
                    while (acc <= -120) { list.incrementCurrentIndex(); acc += 120 }
                }
            }
            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_H || k === Qt.Key_Left) decrementCurrentIndex()
                else if (k === Qt.Key_L || k === Qt.Key_Right) incrementCurrentIndex()
                else if (k === Qt.Key_U) currentIndex = Math.max(0, currentIndex - visibleCount)
                else if (k === Qt.Key_D) currentIndex = Math.min(count - 1, currentIndex + visibleCount)
                else if (k === Qt.Key_G) currentIndex = (event.modifiers & Qt.ShiftModifier) ? count - 1 : 0
                else if (k === Qt.Key_R) currentIndex = Math.floor(Math.random() * count)
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.choose(currentIndex)
                else if (k === Qt.Key_Escape || k === Qt.Key_Q) root.done()
                else return
                event.accepted = true
            }

            delegate: Item {
                id: tile
                required property string modelData
                required property int index
                readonly property bool current: ListView.isCurrentItem

                width: list.tileW
                height: list.height

                Item {
                    anchors.fill: parent

                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(
                            1, Config.pickerSkew, 0, -Config.pickerSkew * tile.height / 2,
                            0, 1, 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1)
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + tile.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.height: list.tileH
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: tile.current
                        color: "transparent"
                        border.width: 4
                        border.color: Colors.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            list.currentIndex = tile.index
                            root.choose(tile.index)
                        }
                    }
                }
            }
        }
    }
}
