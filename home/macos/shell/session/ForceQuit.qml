import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// « Force Quit Applications » (Cmd+Opt+Échap) : liste des apps ouvertes
// (icône + nom), sélection accent, bouton « Force Quit » (« Relaunch » pour le
// Finder) qui demande confirmation puis envoie SIGKILL aux processus de l'app.
// Mise en page relevée sur la capture Tahoe 26 de 512pixels : fenêtre de
// 338 x 320 pt, barre de titre de 31 pt avec séparateur, liste carrée encadrée
// (lignes de 22 pt), indice 11 pt en bas à gauche, bouton 24 pt en bas à droite.
Scope {
    id: root

    property bool shown: false
    property int selected: 0
    property string confirmClass: ""   // app en attente de confirmation
    readonly property var apps: Windows.runningClasses
    readonly property bool dryRun: Quickshell.env("QS_SESSION_DEBUG") === "1"

    function open() {
        // lastIpcObject (classe, pid) n'est rempli qu'après un rafraîchissement
        Hyprland.refreshToplevels();
        selected = Math.max(0, apps.indexOf(Windows.activeClass));
        confirmClass = "";
        shown = true;
    }

    function pidsOf(cls) {
        const set = [];
        for (const t of Windows.windowsOf(cls)) {
            const pid = t?.lastIpcObject?.pid;
            if (pid && pid > 1 && !set.includes(pid)) set.push(pid);
        }
        return set;
    }

    // Le Finder (gestionnaire de fichiers du Dock) se « relance » au lieu de quitter
    function isFinder(cls) { return /^(nemo|org\.gnome\.nautilus|nautilus|finder)$/i.test(cls ?? ""); }
    readonly property bool finderSelected: isFinder(apps[selected])

    function forceQuit(cls) {
        const pids = pidsOf(cls);
        confirmClass = "";
        if (pids.length === 0) return;
        const cmd = ["kill", "-9"].concat(pids.map(String));
        if (dryRun) {
            console.info("[session] (simulation) " + cmd.join(" "));
            return;
        }
        Quickshell.execDetached(cmd);
        if (isFinder(cls)) relaunch.restart();
    }
    Timer {
        id: relaunch
        interval: 600
        onTriggered: Apps.launch(Apps.pinned[0] ?? "nemo")
    }

    GlobalShortcut {
        appid: "macos"
        name: "forcequit"
        description: "Force Quit Applications"
        onPressed: root.shown ? (root.shown = false) : root.open()
    }

    // Banc de test : affiche la feuille de confirmation pour l'app sélectionnée
    IpcHandler {
        target: "forcequit-debug"
        enabled: root.dryRun
        function confirm(): void { root.confirmClass = root.apps[root.selected] ?? ""; }
        function pids(): string { return JSON.stringify(root.pidsOf(root.apps[root.selected] ?? "")); }
    }

    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "forcequit") {
                ShellState.close();
                root.open();
            }
        }
    }

    TahoeWindow {
        id: win
        shown: root.shown
        title: "Force Quit Applications"
        titleSeparator: true
        zoomEnabled: true
        cardWidth: 338
        cardHeight: 320
        onCloseRequested: root.shown = false

        Item {
            id: body
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.confirmClass !== "" ? (root.confirmClass = "") : (root.shown = false)
            Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
            Keys.onDownPressed: root.selected = Math.min(root.apps.length - 1, root.selected + 1)
            Keys.onReturnPressed: {
                if (root.confirmClass !== "") root.forceQuit(root.confirmClass);
                else if (root.apps.length) root.confirmClass = root.apps[root.selected];
            }

            Text {
                id: intro
                x: 20
                y: 21
                width: parent.width - 40
                wrapMode: Text.Wrap
                text: "If an app doesn’t respond for a while, select its name and click " + (root.finderSelected ? "Relaunch." : "Force Quit.")
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.label
            }

            // Liste encadrée (coins droits, liseré d'un demi-point)
            Rectangle {
                id: listBox
                x: 20
                y: 61
                width: parent.width - 40
                height: 168
                color: Theme.dark ? Qt.rgba(0, 0, 0, 0.22) : "white"
                border.width: 0.5
                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 1
                    model: root.apps
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        id: row
                        required property string modelData
                        required property int index
                        readonly property bool sel: index === root.selected
                        width: list.width
                        height: 22

                        // Sélection pleine largeur (#2A62D9 mesuré)
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.dark ? "#0F5BD6" : "#2A62D9"
                            visible: row.sel
                        }
                        Image {
                            x: 9
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            source: Apps.icon(row.modelData)
                        }
                        Text {
                            x: 32
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 38
                            elide: Text.ElideRight
                            text: Apps.displayName(row.modelData)
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: row.sel ? "white" : Theme.label
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selected = row.index
                            onDoubleClicked: root.confirmClass = row.modelData
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.apps.length === 0
                    text: "No Apps Open"
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.labelTertiary
                }
            }

            Text {
                id: hint
                x: 20
                y: 243
                width: btn.x - x - 8
                wrapMode: Text.Wrap
                text: "You can open this window by pressing Command-Option-Escape."
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.label
            }

            TahoeButton {
                id: btn
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                implicitHeight: 24
                radius: 6
                text: root.finderSelected ? "Relaunch" : "Force Quit"
                isDefault: true
                enabled: root.apps.length > 0
                onClicked: root.confirmClass = root.apps[root.selected] ?? ""
            }

            // Feuille de confirmation (alerte Tahoe accrochée en haut de la fenêtre)
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: -win.titleBarHeight
                radius: win.radius
                color: Qt.rgba(0, 0, 0, 0.12)
                opacity: root.confirmClass !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                MouseArea { anchors.fill: parent }

                Item {
                    id: sheet
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.confirmClass !== "" ? 30 : 10
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpring } }
                    width: 260
                    height: sheetCol.implicitHeight + 36

                    SessionGlass {
                        anchors.fill: parent
                        radius: 24
                        tint: Theme.dark ? Qt.rgba(0.16, 0.16, 0.17, 0.97) : Qt.rgba(0.96, 0.96, 0.965, 0.98)
                        shadowOffset: 10
                    }
                    Column {
                        id: sheetCol
                        x: 16
                        y: 20
                        width: parent.width - 32
                        Image {
                            x: 4
                            width: 64
                            height: 64
                            sourceSize: Qt.size(128, 128)
                            source: root.confirmClass ? Apps.icon(root.confirmClass) : ""
                        }
                        Item { width: 1; height: 14 }
                        Text {
                            x: 4
                            width: parent.width - 8
                            wrapMode: Text.Wrap
                            text: "Do you want to force “" + Apps.displayName(root.confirmClass) + "” to quit?"
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Theme.label
                        }
                        Item { width: 1; height: 9 }
                        Text {
                            x: 4
                            width: parent.width - 8
                            wrapMode: Text.Wrap
                            text: "You will lose any unsaved changes."
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: Theme.label
                        }
                        Item { width: 1; height: 18 }
                        Row {
                            width: parent.width
                            spacing: 8
                            TahoeButton {
                                width: (parent.width - 8) / 2
                                text: "Cancel"
                                onClicked: root.confirmClass = ""
                            }
                            TahoeButton {
                                width: (parent.width - 8) / 2
                                text: "Force Quit"
                                isDefault: true
                                onClicked: root.forceQuit(root.confirmClass)
                            }
                        }
                    }
                }
            }
        }
    }
}
