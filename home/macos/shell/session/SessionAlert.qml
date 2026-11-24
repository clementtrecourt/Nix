import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services

// Alertes « Shut Down / Restart / Log Out » de macOS Tahoe : alerte centrée,
// icône et textes alignés à gauche (nouveauté Tahoe), case « Reopen windows
// when logging back in », compte à rebours de 60 s, boutons capsule Cancel /
// action (par défaut, Entrée). Échap annule.
// Métriques (alertes Tahoe 26, captures 512pixels) : 260 pt de large, textes
// à 20 pt du bord, titre gras 13 pt, texte 13 pt, boutons de 28 pt à 16 pt du
// bord, 8 pt entre eux.
Scope {
    id: root

    property string kind: ""        // "shutdown" | "restart" | "logout"
    property bool shown: false
    property int remaining: 60
    // Banc de test : n'exécute rien de réel
    readonly property bool dryRun: Quickshell.env("QS_SESSION_DEBUG") === "1"

    function seconds(n) { return n + (n === 1 ? " second." : " seconds."); }
    readonly property var texts: ({
        shutdown: {
            title: "Are you sure you want to shut down your computer now?",
            body: n => "If you do nothing, the computer will shut down automatically in " + root.seconds(n),
            button: "Shut Down"
        },
        restart: {
            title: "Are you sure you want to restart your computer now?",
            body: n => "If you do nothing, the computer will restart automatically in " + root.seconds(n),
            button: "Restart"
        },
        logout: {
            title: "Are you sure you want to quit all apps and log out now?",
            body: n => "If you do nothing, you will be logged out automatically in " + root.seconds(n),
            button: "Log Out"
        }
    })
    readonly property var t: texts[kind] ?? texts.shutdown

    function ask(k) {
        kind = k;
        remaining = 60;
        reopen.checked = true;
        shown = true;
    }
    function cancel() { shown = false; }
    function confirm() {
        shown = false;
        const cmd = kind === "shutdown" ? ["systemctl", "poweroff"]
                  : kind === "restart" ? ["systemctl", "reboot"]
                  : null;
        if (dryRun) {
            console.info("[session] (simulation) " + (cmd ? cmd.join(" ") : "hyprctl dispatch exit"));
            return;
        }
        if (cmd) Quickshell.execDetached(cmd);
        else Hyprland.dispatch("exit");
    }

    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            const p = ShellState.openPanel;
            if (p === "shutdown" || p === "restart" || p === "logout") {
                root.ask(p);
                ShellState.close();
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0) root.confirm();
        }
    }

    TahoeWindow {
        id: win
        shown: root.shown
        titleBar: false
        exclusiveKeyboard: true
        cardWidth: 260
        cardHeight: col.implicitHeight + 36

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.cancel()
            Keys.onReturnPressed: root.confirm()
            Keys.onEnterPressed: root.confirm()

            Column {
                id: col
                x: 16
                y: 20
                width: parent.width - 32
                spacing: 0

                // Icône Tahoe : disque gris "verre" + pictogramme d'alimentation
                // (même icône pour Éteindre / Redémarrer / Fermer la session)
                Item {
                    x: 4
                    width: 64
                    height: 64
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.dark ? "#8E8E93" : "#B4B4B9" }
                            GradientStop { position: 1; color: Theme.dark ? "#6C6C71" : "#97979D" }
                        }
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, Theme.dark ? 0.18 : 0.35)
                    }
                    Symbol {
                        anchors.centerIn: parent
                        name: root.kind === "logout" ? "rectangle.portrait.and.arrow.right" : "power"
                        size: 32
                        color: "white"
                    }
                }
                Item { width: 1; height: 14 }
                Text {
                    x: 4
                    width: parent.width - 8
                    text: root.t.title
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.label
                }
                Item { width: 1; height: 9 }
                Text {
                    x: 4
                    width: parent.width - 8
                    text: root.t.body(root.remaining)
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.label
                }
                Item { width: 1; height: 14 }
                TahoeCheckbox {
                    id: reopen
                    x: 4
                    width: parent.width - 8
                    text: "Reopen windows when logging back in"
                    fontSize: 13
                    checked: true
                }
                Item { width: 1; height: 18 }
                // Boutons côte à côte ; empilés pleine largeur (action par défaut
                // en haut) si un libellé ne tient pas, comme les alertes Tahoe.
                Item {
                    id: buttons
                    width: parent.width
                    readonly property real half: (width - 8) / 2
                    // (implicitWidth = libellé + 32 ; on tolère une marge intérieure de 10 px)
                    readonly property bool stacked: cancelBtn.implicitWidth - 12 > half || okBtn.implicitWidth - 12 > half
                    height: stacked ? okBtn.height * 2 + 8 : okBtn.height
                    TahoeButton {
                        id: cancelBtn
                        width: buttons.stacked ? buttons.width : buttons.half
                        y: buttons.stacked ? okBtn.height + 8 : 0
                        text: "Cancel"
                        onClicked: root.cancel()
                    }
                    TahoeButton {
                        id: okBtn
                        width: buttons.stacked ? buttons.width : buttons.half
                        x: buttons.stacked ? 0 : buttons.half + 8
                        text: root.t.button
                        isDefault: true
                        onClicked: root.confirm()
                    }
                }
            }
        }
    }
}
