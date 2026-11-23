import QtQuick
import qs.common

// Champ de texte Tahoe : coins arrondis (8 px), fond clair/sombre, liseré fin,
// anneau de focus accent (3 px, semi-transparent) comme AppKit.
FocusScope {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder
    property bool password: false
    property bool readOnly: false
    signal accepted()

    implicitWidth: 200
    implicitHeight: 28

    // Anneau de focus
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: bg.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Qt.alpha(Theme.accent, 0.45)
        opacity: input.activeFocus ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : "white"
        border.width: 0.5
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        text: root.placeholder
        visible: input.text.length === 0
        font: input.font
        color: Theme.labelTertiary
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        readOnly: root.readOnly
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.label
        selectionColor: Qt.alpha(Theme.accent, 0.4)
        selectedTextColor: Theme.label
        clip: true
        onAccepted: root.accepted()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.readOnly ? Qt.ArrowCursor : Qt.IBeamCursor
        onPressed: mouse => { input.forceActiveFocus(); mouse.accepted = false; }
    }
}
