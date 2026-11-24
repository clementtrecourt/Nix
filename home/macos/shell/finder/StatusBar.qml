import QtQuick
import qs.common

// Barre d'état (⌘/) : « 1 of 5 selected, 2.27 TB available » centré, gris,
// 11 pt, sous un filet (capture MacStories, Six Colors).
Item {
    id: root
    required property var fw

    readonly property int count: fw.items.length
    readonly property int nsel: fw.selection.length
    readonly property string text: {
        let s = nsel > 0 ? nsel + " of " + count + " selected" : Fs.itemsLabel(count);
        if (fw.freeBytes >= 0) s += ", " + Fs.formatAvail(fw.freeBytes) + " available";
        return s;
    }

    Rectangle { anchors.fill: parent; color: FStyle.contentBg }
    Rectangle { width: parent.width; height: 1; color: FStyle.gridLine }
    Text {
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: 11
        color: FStyle.secondaryText
    }
}
