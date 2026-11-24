import QtQuick
import qs.common

// Champ de renommage en place (Entrée sur un élément, ou clic lent sur son
// nom) : fond du contenu, liseré d'accent, nom sans extension présélectionné
// comme dans le Finder. Entrée / perte du focus = valider, Échap = annuler.
Rectangle {
    id: root

    required property var fw
    required property var entry
    property bool centered: false
    property int fontSize: 13
    // Largeur maximale (présentation Icônes : le champ s'élargit avec le texte)
    property real maxWidth: 400

    readonly property real textWidth: Math.min(maxWidth - 8, Math.max(40, input.contentWidth + 10))
    implicitWidth: textWidth + 8
    implicitHeight: input.contentHeight + 4
    color: FStyle.contentBg
    radius: 3
    border.width: 1
    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.75)

    property bool _done: false
    function commit() {
        if (_done) return;
        _done = true;
        fw.commitRename(entry, input.text);
    }
    function cancel() {
        if (_done) return;
        _done = true;
        fw.renamingPath = "";
        fw.focusStage();
    }

    TextInput {
        id: input
        x: 4
        y: 2
        width: root.width - 8
        text: root.entry.name
        font.family: Theme.font
        font.pixelSize: root.fontSize
        color: Theme.label
        selectionColor: Theme.dark ? Qt.rgba(0.25, 0.45, 0.8, 1) : Qt.rgba(0.70, 0.83, 1, 1)
        selectedTextColor: Theme.label
        horizontalAlignment: root.centered ? TextInput.AlignHCenter : TextInput.AlignLeft
        wrapMode: root.centered ? TextInput.WrapAnywhere : TextInput.NoWrap
        clip: !root.centered
        selectByMouse: true
        Component.onCompleted: {
            forceActiveFocus();
            const sp = Fs.splitName(root.entry.name, root.entry.isDir);
            select(0, sp.ext && sp.base ? sp.base.length : text.length);
        }
        Keys.onReturnPressed: root.commit()
        Keys.onEnterPressed: root.commit()
        Keys.onEscapePressed: root.cancel()
        Keys.onTabPressed: root.commit()
        onActiveFocusChanged: if (!activeFocus) root.commit()
    }
}
