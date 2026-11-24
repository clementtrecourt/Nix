import QtQuick
import qs.common

// En-tête d'un module déplié : titre en gras + interrupteur optionnel.
Item {
    id: h

    property string title
    property bool hasSwitch: false
    property bool checked: false
    property bool switchEnabled: true
    signal toggled(bool on)

    implicitWidth: CCStyle.width
    implicitHeight: 44

    Text {
        renderType: Text.NativeRendering
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        text: h.title
        color: CCStyle.text
        font.family: Theme.font
        font.letterSpacing: CCStyle.tracking
        font.pixelSize: CCStyle.headerSize
        font.weight: Font.Bold
    }

    Switch {
        visible: h.hasSwitch
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        checked: h.checked
        enabled: h.switchEnabled
        opacity: h.switchEnabled ? 1 : CCStyle.disabledOpacity
        onToggled: on => h.toggled(on)
    }
}
