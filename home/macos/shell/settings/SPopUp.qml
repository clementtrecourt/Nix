import QtQuick
import Quickshell
import qs.common

// Bouton local (pop-up button) des formulaires de Tahoe : valeur en 13 pt puis
// pastille ronde grise de 19 pt portant ⌃⌄ (capture Apple mh15217 : « Medium »,
// « Automatic »). Le menu s'ouvre de sorte que l'élément choisi recouvre le
// bouton, comme sur Mac.
//
// options : ["Never", …] ou [{ text, value, separator?, enabled? }]
Item {
    id: root

    property var options: []
    property var value
    property bool enabledPopUp: true
    property color swatch: "transparent"     // pastille de couleur devant la valeur
    signal activated(var value)

    readonly property var _opts: options.map(o => typeof o === "object" && o !== null ? o : ({ text: String(o), value: o }))
    readonly property int _index: _opts.findIndex(o => !o.separator && o.value === value)
    readonly property string currentText: _index >= 0 ? _opts[_index].text : (value !== undefined ? String(value) : "")

    implicitWidth: row.implicitWidth
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight
    opacity: enabledPopUp ? 1 : 0.45

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Rectangle {
            visible: root.swatch.a > 0
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            color: root.swatch
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentText
            font.family: Theme.font
            font.pixelSize: SStyle.body
            color: SStyle.label
        }
        Rectangle {
            width: 19
            height: 19
            radius: 9.5
            anchors.verticalCenter: parent.verticalCenter
            color: ma.pressed ? SStyle.controlFillPressed : SStyle.popupCircle
            Symbol {
                anchors.centerIn: parent
                name: "chevron.up.chevron.down"
                size: 12
                color: SStyle.label
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -3
        enabled: root.enabledPopUp
        onClicked: root.popup(false)
    }

    function popup(noGrab) {
        const w = QsWindow.window;
        if (!w || !w.showMenu) return;
        const items = root._opts.map(o => o.separator ? { separator: true }
            : { text: o.text, checked: o.value === root.value, enabled: o.enabled !== false,
                action: () => { root.activated(o.value); } });
        // Ligne choisie sous le bouton : rangées de 24 pt, marge de 5 pt
        let off = 5;
        for (let i = 0; i < Math.max(0, root._index); ++i) off += items[i].separator ? 11 : 24;
        const p = label.mapToItem(null, 0, label.height / 2);
        w.showMenu(Qt.point(p.x - 33, p.y - off - 12), items, noGrab);
    }
}
