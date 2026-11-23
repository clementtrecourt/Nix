import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services

// Alertes "Éteindre / Redémarrer / Fermer la session" de macOS Tahoe :
// alerte centrée, icône et textes alignés à gauche (nouveauté Tahoe), case
// "Rouvrir les fenêtres…", compte à rebours de 60 s, boutons capsule
// Annuler / action (par défaut, Entrée). Échap annule.
Scope {
    id: root

    property string kind: ""        // "shutdown" | "restart" | "logout"
    property bool shown: false
    property int remaining: 60
    // Banc de test : n'exécute rien de réel
    readonly property bool dryRun: Quickshell.env("QS_SESSION_DEBUG") === "1"

    readonly property var texts: ({
        shutdown: {
            title: "Voulez-vous vraiment éteindre votre ordinateur maintenant ?",
            body: n => "Si vous ne faites rien, l’ordinateur s’éteindra automatiquement dans " + n + " seconde" + (n > 1 ? "s" : "") + ".",
            button: "Éteindre"
        },
        restart: {
            title: "Voulez-vous vraiment redémarrer votre ordinateur maintenant ?",
            body: n => "Si vous ne faites rien, l’ordinateur redémarrera automatiquement dans " + n + " seconde" + (n > 1 ? "s" : "") + ".",
            button: "Redémarrer"
        },
        logout: {
            title: "Voulez-vous vraiment quitter toutes les apps et fermer la session maintenant ?",
            body: n => "Si vous ne faites rien, votre session sera automatiquement fermée dans " + n + " seconde" + (n > 1 ? "s" : "") + ".",
            button: "Fermer la session"
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
        cardHeight: col.implicitHeight + 40

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.cancel()
            Keys.onReturnPressed: root.confirm()
            Keys.onEnterPressed: root.confirm()

            Column {
                id: col
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 0

                Image {
                    width: 64
                    height: 64
                    sourceSize: Qt.size(128, 128)
                    source: Quickshell.iconPath("computer", "nix-snowflake")
                    smooth: true
                }
                Item { width: 1; height: 14 }
                Text {
                    width: parent.width
                    text: root.t.title
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.label
                }
                Item { width: 1; height: 8 }
                Text {
                    width: parent.width
                    text: root.t.body(root.remaining)
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 11
                    lineHeight: 1.1
                    color: Theme.label
                }
                Item { width: 1; height: 14 }
                TahoeCheckbox {
                    id: reopen
                    width: parent.width
                    text: "Rouvrir les fenêtres lors de la prochaine connexion"
                    checked: true
                }
                Item { width: 1; height: 18 }
                Row {
                    width: parent.width
                    spacing: 8
                    TahoeButton {
                        width: (parent.width - 8) / 2
                        text: "Annuler"
                        onClicked: root.cancel()
                    }
                    TahoeButton {
                        width: (parent.width - 8) / 2
                        text: root.t.button
                        isDefault: true
                        onClicked: root.confirm()
                    }
                }
            }
        }
    }
}
