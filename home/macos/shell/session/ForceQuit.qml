import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// "Forcer à quitter des applications" (Cmd+Opt+Échap) : liste des apps
// ouvertes (icône + nom), sélection accent, bouton "Forcer à quitter" qui
// demande confirmation puis envoie SIGKILL aux processus de l'app.
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

    function forceQuit(cls) {
        const pids = pidsOf(cls);
        confirmClass = "";
        if (pids.length === 0) return;
        const cmd = ["kill", "-9"].concat(pids.map(String));
        if (dryRun) console.info("[session] (simulation) " + cmd.join(" "));
        else Quickshell.execDetached(cmd);
    }

    GlobalShortcut {
        appid: "macos"
        name: "forcequit"
        description: "Forcer à quitter des applications"
        onPressed: root.shown ? (root.shown = false) : root.open()
    }

    // Banc de test : affiche la feuille de confirmation pour l'app sélectionnée
    IpcHandler {
        target: "forcequit-debug"
        enabled: root.dryRun
        function confirm(): void { root.confirmClass = root.apps[root.selected] ?? ""; }
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
        title: "Forcer à quitter des applications"
        cardWidth: 352
        cardHeight: 430
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
                y: 4
                width: parent.width - 40
                wrapMode: Text.Wrap
                text: "Si une app ne répond pas pendant un certain temps, sélectionnez son nom et cliquez sur Forcer à quitter."
                font.family: Theme.font
                font.pixelSize: 11
                lineHeight: 1.1
                color: Theme.label
            }

            // Liste encadrée
            Rectangle {
                id: listBox
                x: 20
                anchors.top: intro.bottom
                anchors.topMargin: 12
                width: parent.width - 40
                anchors.bottom: hint.top
                anchors.bottomMargin: 12
                radius: 10
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : "white"
                border.width: 0.5
                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12)
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 5
                    model: root.apps
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        id: row
                        required property string modelData
                        required property int index
                        readonly property bool sel: index === root.selected
                        width: list.width
                        height: 24

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Theme.accent
                            visible: row.sel
                        }
                        Image {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            source: Apps.icon(row.modelData)
                        }
                        Text {
                            x: 28
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34
                            elide: Text.ElideRight
                            text: Apps.name(row.modelData)
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
                    text: "Aucune app ouverte"
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.labelTertiary
                }
            }

            Text {
                id: hint
                x: 20
                anchors.bottom: btn.top
                anchors.bottomMargin: 14
                width: parent.width - 40
                wrapMode: Text.Wrap
                text: "Vous pouvez ouvrir cette fenêtre en appuyant sur Commande + Option + Échap."
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.labelSecondary
            }

            TahoeButton {
                id: btn
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                implicitHeight: 24
                text: "Forcer à quitter"
                isDefault: true
                enabled: root.apps.length > 0
                onClicked: root.confirmClass = root.apps[root.selected] ?? ""
            }

            // Feuille de confirmation (assombrit la fenêtre, carte centrée en haut)
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: -win.titleBarHeight
                radius: win.radius
                color: Qt.rgba(0, 0, 0, 0.18)
                opacity: root.confirmClass !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                MouseArea { anchors.fill: parent }

                Item {
                    id: sheet
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.confirmClass !== "" ? 46 : 20
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpring } }
                    width: 284
                    height: sheetCol.implicitHeight + 40

                    Glass {
                        anchors.fill: parent
                        radius: 22
                        tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.97) : Qt.rgba(0.98, 0.98, 0.98, 0.98)
                        shadowOffset: 10
                    }
                    Column {
                        id: sheetCol
                        x: 20
                        y: 20
                        width: parent.width - 40
                        Image {
                            width: 56
                            height: 56
                            sourceSize: Qt.size(112, 112)
                            source: root.confirmClass ? Apps.icon(root.confirmClass) : ""
                        }
                        Item { width: 1; height: 12 }
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Voulez-vous forcer « " + Apps.name(root.confirmClass) + " » à quitter ?"
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Theme.label
                        }
                        Item { width: 1; height: 6 }
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Vous perdrez toutes les modifications non enregistrées."
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.label
                        }
                        Item { width: 1; height: 16 }
                        Row {
                            width: parent.width
                            spacing: 8
                            TahoeButton {
                                width: (parent.width - 8) / 2
                                text: "Annuler"
                                onClicked: root.confirmClass = ""
                            }
                            TahoeButton {
                                width: (parent.width - 8) / 2
                                text: "Forcer à quitter"
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
