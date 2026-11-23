import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Menu contextuel du bureau (clic droit sur le fond d'écran), comme le Finder
// de macOS Tahoe :
//   Nouveau dossier | Lire les informations, Changer le fond d'écran…,
//   Modifier les widgets… | Utiliser les piles, Trier par ▸, Aligner,
//   Aligner par ▸, Afficher les options de présentation
// Surface plein écran transparente : un clic en dehors du menu le ferme.
// Comme AppKit : ouverture instantanée, fermeture en fondu (≈ 150 ms) ; le
// clavier est pris pendant l'ouverture (flèches, Entrée, Échap, lettres).
//
// Le shell n'affiche pas d'icônes sur le bureau : « Utiliser les piles »,
// « Trier par » et « Aligner (par) » gardent leur état (coches) mais n'ont,
// comme sur un bureau macOS vide, aucun effet visible.
Scope {
    id: root

    property var screen: null
    property real menuX: 0
    property real menuY: 0
    property bool shown: false
    // Fondu de fermeture en cours (la surface reste le temps du fondu)
    property bool closing: false

    // État des options de présentation du bureau
    property bool useStacks: false
    property string sortBy: "none"       // none | grid | name | kind | …
    property string cleanUpBy: ""

    signal changeWallpaper()

    // Surface du menu ouvert (banc de test)
    property var win: null

    function popup(scr, x, y) {
        closing = false;
        screen = scr;
        menuX = x;
        menuY = y;
        shown = true;
    }
    function dismiss() {
        if (!shown || closing) return;
        closing = true;
        fadeOut.restart();
    }

    // Un autre panneau (alerte, Spotlight…) s'ouvre : le menu se ferme
    Connections {
        target: ShellState
        function onOpenPanelChanged() { root.dismiss(); }
    }

    readonly property string home: Quickshell.env("HOME")
    readonly property string desktopDir: home + "/Desktop"

    function newFolder() {
        // "dossier sans titre", "dossier sans titre 2", … comme le Finder
        Quickshell.execDetached(["sh", "-c",
            'd="$1"; mkdir -p "$d"; n="dossier sans titre"; i=2; p="$d/$n"; ' +
            'while [ -e "$p" ]; do p="$d/$n $i"; i=$((i+1)); done; mkdir "$p"',
            "sh", desktopDir]);
    }
    // Interface freedesktop FileManager1 (Nautilus, Dolphin, Nemo…)
    function fileManager(method) {
        Quickshell.execDetached(["dbus-send", "--session", "--type=method_call",
            "--dest=org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
            "org.freedesktop.FileManager1." + method,
            "array:string:file://" + desktopDir, "string:"]);
    }

    readonly property var sortItems: [
        { text: "Aucun", value: "none" },
        { text: "Aligner sur la grille", value: "grid" },
        { separator: true },
        { text: "Nom", value: "name" },
        { text: "Type", value: "kind" },
        { text: "Date de dernière ouverture", value: "opened" },
        { text: "Date d’ajout", value: "added" },
        { text: "Date de modification", value: "modified" },
        { text: "Date de création", value: "created" },
        { text: "Taille", value: "size" },
        { text: "Tags", value: "tags" }
    ]
    function checkedList(list, current) {
        return list.map(i => i.separator ? i : Object.assign({}, i, { checked: i.value === current }));
    }

    readonly property var items: [
        { text: "Nouveau dossier", icon: "folder.badge.plus", action: "newfolder" },
        { separator: true },
        { text: "Lire les informations", icon: "info.circle", action: "info" },
        { text: "Changer le fond d’écran…", icon: "photo", action: "wallpaper" },
        { text: "Modifier les widgets…", icon: "square.grid.2x2", action: "widgets" },
        { separator: true },
        { text: "Utiliser les piles", icon: "square.stack.3d.up", action: "stacks", checked: root.useStacks },
        { text: "Trier par", icon: "arrow.up.arrow.down", submenu: root.checkedList(root.sortItems, root.sortBy), kind: "sort" },
        { text: "Aligner", icon: "square.grid.3x3", action: "cleanup", enabled: !root.useStacks },
        { text: "Aligner par", icon: "list.bullet", submenu: root.sortItems.slice(3), kind: "cleanupby", enabled: !root.useStacks },
        { text: "Afficher les options de présentation", icon: "eye", action: "viewoptions" }
    ]

    function run(item) {
        root.dismiss();
        switch (item.action) {
        case "newfolder": root.newFolder(); break;
        case "info": root.fileManager("ShowItemProperties"); break;
        case "wallpaper": root.changeWallpaper(); break;
        case "widgets": ShellState.open("notificationcenter"); break;
        case "stacks": root.useStacks = !root.useStacks; break;
        case "cleanup": break;
        // Options de présentation : vue du dossier Bureau dans le gestionnaire de fichiers
        case "viewoptions": root.fileManager("ShowFolders"); break;
        }
    }

    LazyLoader {
        active: root.shown && root.screen !== null

        PanelWindow {
            id: win
            screen: root.screen
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "macos-menu"
            // Menu ouvert = clavier pris (Échap, flèches, lettres), comme AppKit
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            Component.onCompleted: root.win = win
            // Banc de test : simule une touche ("up", "down", "right", "left", "return", lettre)
            function debugKey(k) {
                const m = subMenu.activeFocus ? subMenu : menu;
                if (k === "up") m.move(-1);
                else if (k === "down") m.move(1);
                else if (k === "right") { if (sub) subMenu.enter(); }
                else if (k === "left") m.back();
                else if (k === "return") m.activate(m.current);
                else if (k === "escape") { if (m === subMenu) m.back(); else root.dismiss(); }
                else m.jump(k);
            }

            // Sous-menu affiché (ligne parente + position)
            property var sub: null
            property real subY: 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: root.dismiss()
            }

            Item {
                id: menus
                anchors.fill: parent
                opacity: root.closing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                TahoeMenu {
                    id: menu
                    focus: true
                    // Ouvert vers le bas-droite du pointeur, replié si l'écran manque
                    x: Math.min(root.menuX, win.width - width - 6)
                    y: root.menuY + height > win.height - 6 ? Math.max(6, root.menuY - height) : root.menuY
                    width: implicitWidth
                    height: implicitHeight
                    items: root.items

                    Keys.onEscapePressed: root.dismiss()
                    Keys.onRightPressed: if (win.sub) subMenu.enter()
                    onSubmenuRequested: (item, rowY) => {
                        win.sub = item;
                        win.subY = rowY;
                    }
                    onTriggered: item => root.run(item)
                }

                // Sous-menu (Trier par, Aligner par) : à droite de la ligne,
                // sa première ligne alignée sur la ligne parente
                TahoeMenu {
                    id: subMenu
                    visible: win.sub !== null
                    items: win.sub ? win.sub.submenu : []
                    minWidth: 180
                    width: implicitWidth
                    height: implicitHeight
                    x: menu.x + menu.width + width - 3 > win.width
                        ? menu.x - width + 3 : menu.x + menu.width - 3
                    y: Math.max(6, Math.min(menu.y + win.subY - padding, win.height - height - 6))

                    function enter() {
                        forceActiveFocus();
                        move(1);
                    }
                    onBack: {
                        current = -1;
                        menu.forceActiveFocus();
                    }
                    Keys.onEscapePressed: back()
                    onTriggered: item => {
                        if (win.sub?.kind === "sort") root.sortBy = item.value;
                        else root.cleanUpBy = item.value;
                        root.dismiss();
                    }
                }
            }
        }
    }

    // Fermeture : fondu puis destruction de la surface
    SequentialAnimation {
        id: fadeOut
        PauseAnimation { duration: 160 }
        ScriptAction {
            script: {
                root.shown = false;
                root.closing = false;
            }
        }
    }
}
