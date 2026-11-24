import QtQuick
import qs.common

// Curseur de Tahoe : rail de 4 pt (accent jusqu'au bouton), bouton en pilule
// blanche de 20 × 13 pt ombrée ; graduations facultatives (`ticks`) et
// libellés aux extrémités (`minLabel` / `maxLabel`, 11 pt gris, sous le rail).
Item {
    id: root

    property real value: 0          // 0..1
    property int ticks: 0           // nombre de crans (0 = continu)
    property bool snap: ticks > 1
    property string minLabel
    property string maxLabel
    property string minSymbol
    property string maxSymbol
    property bool enabledSlider: true
    signal moved(real value)
    signal released(real value)

    implicitWidth: 220
    implicitHeight: (minLabel || maxLabel) ? 34 : 20
    opacity: enabledSlider ? 1 : 0.45

    readonly property real _sideL: minSymbol ? 22 : 0
    readonly property real _sideR: maxSymbol ? 22 : 0
    readonly property real _x0: _sideL + 10
    readonly property real _w: width - _sideL - _sideR - 20
    readonly property real _cy: 10

    Symbol {
        visible: root.minSymbol !== ""
        name: root.minSymbol
        size: 13
        y: root._cy - 6.5
        color: SStyle.secondary
    }
    Symbol {
        visible: root.maxSymbol !== ""
        name: root.maxSymbol
        size: 15
        x: root.width - 16
        y: root._cy - 7.5
        color: SStyle.secondary
    }

    Rectangle {
        x: root._x0
        y: root._cy - 2
        width: root._w
        height: 4
        radius: 2
        color: SStyle.sliderTrack
        Rectangle {
            width: Math.max(4, root.value * parent.width)
            height: parent.height
            radius: 2
            color: SStyle.accent
            visible: root.ticks <= 1
        }
    }
    Repeater {
        model: root.ticks > 1 ? root.ticks : 0
        Rectangle {
            required property int index
            x: root._x0 + index / (root.ticks - 1) * root._w - 1
            y: root._cy + 5
            width: 2
            height: 4
            radius: 1
            color: SStyle.tertiary
        }
    }
    Rectangle {
        id: knob
        width: 20
        height: 13
        radius: 6.5
        x: root._x0 + root.value * root._w - width / 2
        y: root._cy - height / 2
        color: "#FFFFFF"
        border.width: 0.5
        border.color: Qt.rgba(0, 0, 0, 0.10)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.bottomMargin: -1.5
            z: -1
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.16)
        }
    }
    Text {
        visible: root.minLabel !== ""
        x: root._x0 - 4
        y: root._cy + 10
        text: root.minLabel
        font.family: Theme.font
        font.pixelSize: SStyle.small
        color: SStyle.secondary
    }
    Text {
        visible: root.maxLabel !== ""
        anchors.right: parent.right
        anchors.rightMargin: root._sideR + 6
        y: root._cy + 10
        text: root.maxLabel
        font.family: Theme.font
        font.pixelSize: SStyle.small
        color: SStyle.secondary
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabledSlider
        preventStealing: true
        function at(mx) {
            let v = Math.max(0, Math.min(1, (mx - root._x0) / root._w));
            if (root.snap) v = Math.round(v * (root.ticks - 1)) / (root.ticks - 1);
            return v;
        }
        onPressed: (m) => { root.value = at(m.x); root.moved(root.value); }
        onPositionChanged: (m) => { if (pressed) { const v = at(m.x); if (v !== root.value) { root.value = v; root.moved(v); } } }
        onReleased: root.released(root.value)
    }
}
