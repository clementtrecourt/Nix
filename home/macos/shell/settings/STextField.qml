import QtQuick
import qs.common

// Champ de texte des formulaires (aligné à droite, sans cadre jusqu'à
// l'édition, comme « Name » dans General > About).
Item {
    id: root

    property alias text: input.text
    property string placeholder
    property bool secret: false
    property real fieldWidth: 200
    property bool framed: true
    signal accepted(string text)

    implicitWidth: fieldWidth
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: 6
        visible: root.framed || input.activeFocus
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : "#FFFFFF"
        border.width: input.activeFocus ? 2 : 0.5
        border.color: input.activeFocus ? Qt.rgba(SStyle.accent.r, SStyle.accent.g, SStyle.accent.b, 0.55)
                                        : (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16))
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: root.framed ? TextInput.AlignLeft : TextInput.AlignRight
        clip: true
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        font.family: Theme.font
        font.pixelSize: SStyle.body
        color: root.framed ? SStyle.label : SStyle.secondary
        selectionColor: Qt.rgba(SStyle.accent.r, SStyle.accent.g, SStyle.accent.b, 0.4)
        selectByMouse: true
        onAccepted: root.accepted(text)
    }
    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: !input.text && !input.activeFocus
        text: root.placeholder
        font: input.font
        color: SStyle.tertiary
    }
    function focusField() { input.forceActiveFocus(); input.selectAll(); }
}
