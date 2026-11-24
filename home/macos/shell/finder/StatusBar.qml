import QtQuick
import qs.common

// Barre d'état (⌘/) : « 1 of 5 selected, 2.27 TB available » centré, gris,
// 11 pt, sous un filet (capture MacStories, Six Colors).
Item {
    id: root
    required property var fw

    // Lignes visibles (dossiers déployés compris en Liste), comme Tahoe
    readonly property var _rows: fw.viewItem() && fw.viewItem().flatRows ? fw.viewItem().flatRows : fw.items
    readonly property int count: fw.viewMode === "column" ? fw.items.length : _rows.length
    readonly property int nsel: fw.selection.length
    readonly property string text: {
        let s = nsel > 0 ? nsel + " of " + count + " selected" : Fs.itemsLabel(count);
        if (fw.freeBytes >= 0) s += ", " + Fs.formatAvail(fw.freeBytes) + " available";
        return s;
    }

    Rectangle { anchors.fill: parent; color: FStyle.contentBg }
    Rectangle { width: parent.width; height: 1; color: FStyle.gridLine }
    // Curseur de taille des icônes (présentation Icônes, à droite de la barre
    // d'état : captures MacStories et Eclectic Light)
    Item {
        id: slider
        visible: root.fw.viewMode === "icon"
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 84
        height: 16
        readonly property real minV: 16
        readonly property real maxV: 160
        readonly property real t: (root.fw.iconSize - minV) / (maxV - minV)
        Rectangle {
            y: Math.round((parent.height - height) / 2)
            width: parent.width
            height: 4
            radius: 2
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)
            Rectangle {
                width: Math.round(knob.x + knob.width / 2)
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        Rectangle {
            id: knob
            x: Math.round(slider.t * (slider.width - width))
            y: Math.round((parent.height - height) / 2)
            // Bouton de curseur de Tahoe : petite capsule horizontale
            width: 18
            height: 11
            radius: 5.5
            color: Theme.dark ? "#D6D6D8" : "#FFFFFF"
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, 0.22)
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            function setFrom(x) {
                const t = Math.max(0, Math.min(1, (x - 4 - knob.width / 2) / (slider.width - knob.width)));
                root.fw.iconSize = Math.round((slider.minV + t * (slider.maxV - slider.minV)) / 4) * 4;
            }
            onPressed: (m) => setFrom(m.x)
            onPositionChanged: (m) => { if (pressed) setFrom(m.x); }
        }
    }
    Text {
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: 11
        color: FStyle.secondaryText
    }
}
