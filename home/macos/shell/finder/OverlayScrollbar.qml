import QtQuick
import qs.common

// Barre de défilement « superposée » de macOS : fine pastille grise qui
// apparaît pendant le défilement puis s'estompe, s'élargit au survol et se
// glisse. Verticale (ou horizontale avec horizontal: true).
Item {
    id: root

    required property Flickable flick
    property bool horizontal: false
    // Marges de la piste (ex. sous la barre d'outils)
    property real startMargin: 0
    property real endMargin: 0

    readonly property real _content: horizontal ? flick.contentWidth : flick.contentHeight
    readonly property real _view: horizontal ? flick.width : flick.height
    readonly property real _pos: horizontal ? flick.contentX - flick.originX : flick.contentY - flick.originY
    readonly property real _extra: horizontal ? (flick.leftMargin + flick.rightMargin) : (flick.topMargin + flick.bottomMargin)
    readonly property real _total: _content + _extra
    readonly property bool needed: _total > _view + 1
    readonly property real track: (horizontal ? width : height) - startMargin - endMargin
    readonly property real knob: Math.max(24, track * _view / Math.max(1, _total))
    readonly property real _range: Math.max(1, _total - _view)
    readonly property real _knobPos: startMargin + (track - knob) * Math.max(0, Math.min(1, (_pos + (horizontal ? flick.leftMargin : flick.topMargin)) / _range))

    property bool shown: false
    visible: needed
    Timer { id: hide; interval: 900; onTriggered: root.shown = ma.containsMouse || ma.pressed }
    Connections {
        target: root.flick
        function onContentYChanged() { if (!root.horizontal) { root.shown = true; hide.restart(); } }
        function onContentXChanged() { if (root.horizontal) { root.shown = true; hide.restart(); } }
    }

    width: horizontal ? undefined : 14
    height: horizontal ? 14 : undefined

    Rectangle {
        readonly property real thick: ma.containsMouse || ma.pressed ? 9 : 7
        x: root.horizontal ? root._knobPos : root.width - thick - 3
        y: root.horizontal ? root.height - thick - 3 : root._knobPos
        width: root.horizontal ? root.knob : thick
        height: root.horizontal ? thick : root.knob
        radius: thick / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(0, 0, 0, 0.40)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: if (containsMouse) { root.shown = true; hide.stop(); } else hide.restart()
        property real grab: 0
        function setFrom(v) {
            const t = (v - root.startMargin - root.knob / 2) / Math.max(1, root.track - root.knob);
            const p = Math.max(0, Math.min(1, t)) * root._range - (root.horizontal ? root.flick.leftMargin : root.flick.topMargin);
            if (root.horizontal) root.flick.contentX = p + root.flick.originX;
            else root.flick.contentY = p + root.flick.originY;
        }
        onPressed: (m) => setFrom(root.horizontal ? m.x : m.y)
        onPositionChanged: (m) => { if (pressed) setFrom(root.horizontal ? m.x : m.y); }
    }
}
