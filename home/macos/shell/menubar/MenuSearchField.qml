import QtQuick
import qs.common

// Champ « Rechercher » en tête du menu Aide (comme sur macOS : il cherche dans
// les menus de l'app au premier plan). Il prend le focus clavier à l'ouverture.
Item {
    id: root

    property var panel

    implicitHeight: 34

    Rectangle {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.topMargin: 3
        anchors.bottomMargin: 7
        radius: height / 2
        color: Theme.fill

        Glyph {
            id: glass
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            name: "magnifyingglass"
            size: 13
            tint: Theme.labelSecondary
        }

        TextInput {
            id: input
            anchors.left: glass.right
            anchors.leftMargin: 5
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            renderType: TextInput.CurveRendering
            font.pixelSize: Theme.fontSize
            color: Theme.label
            selectionColor: Theme.accent
            selectedTextColor: "white"
            clip: true
            focus: true
            onTextChanged: root.panel.query = text

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: "Rechercher"
                font: input.font
                color: Theme.labelTertiary
            }

            Keys.onPressed: event => {
                const p = root.panel.deepest();
                if (event.key === Qt.Key_Down) { p.move(1); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { p.move(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { p.keyEnter(); event.accepted = true; }
                else if (event.key === Qt.Key_Escape) { root.panel.controller.close(false); event.accepted = true; }
                else if (event.key === Qt.Key_Left && input.text === "") { root.panel.keyLeft(); event.accepted = true; }
            }
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
