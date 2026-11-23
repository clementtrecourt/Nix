import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.common

// Agent Polkit au style macOS Tahoe : alerte alignée à gauche, icône cadenas,
// "<App> veut effectuer des modifications.", "Saisissez votre mot de passe pour
// autoriser cette action.", champs Nom / Mot de passe, Annuler / OK.
// Mauvais mot de passe : la fenêtre secoue et le champ est vidé.
Scope {
    id: root

    // Flux en cours (AuthFlow réel, ou objet factice du banc de test)
    readonly property var flow: mock ?? agentLoader.item?.flow ?? null
    property var mock: null
    property bool shown: flow !== null && flow !== undefined && !(flow.isCompleted ?? false)
    property int identityIndex: 0
    property int shakeSerial: 0

    // Un seul agent par session logind : sur le banc de test (session hôte qui
    // a déjà le sien) on ne s'enregistre pas, pour un journal propre.
    LazyLoader {
        id: agentLoader
        active: Quickshell.env("QS_SESSION_DEBUG") !== "1"
        PolkitAgent {}
    }

    // Nom lisible de l'app demandeuse, déduit de l'action Polkit
    function appName(actionId) {
        const a = actionId ?? "";
        const known = [
            [/^org\.freedesktop\.systemd1/, "systemd"],
            [/^org\.freedesktop\.NetworkManager/, "Réseau"],
            [/^org\.freedesktop\.(udisks2|UDisks2)/, "Utilitaire de disque"],
            [/^org\.freedesktop\.packagekit/, "Logiciels"],
            [/^org\.freedesktop\.login1/, "Session"],
            [/^org\.freedesktop\.timedate1/, "Date et heure"],
            [/^org\.freedesktop\.hostname1/, "Réglages Système"],
            [/^org\.freedesktop\.locale1/, "Langue et région"],
            [/^org\.freedesktop\.accounts/, "Utilisateurs et groupes"],
            [/^org\.gnome\./, "Réglages Système"],
            [/^org\.freedesktop\.policykit\.exec/, "Terminal"],
            [/^com\.feralinteractive|^org\.blueman|^org\.bluez/, "Bluetooth"]
        ];
        for (const [re, n] of known) if (re.test(a)) return n;
        const parts = a.split(".");
        const p = parts.length > 2 ? parts[2] : (parts[0] || "Une app");
        return p.charAt(0).toUpperCase() + p.slice(1);
    }

    readonly property var identities: flow?.identities ?? []
    readonly property string userLabel: flow?.selectedIdentity?.displayName ?? (identities[0]?.displayName ?? Quickshell.env("USER"))

    function submit() {
        if (!flow || pass.text.length === 0) return;
        flow.submit(pass.text);
        pass.text = "";
    }
    function cancel() {
        if (flow) flow.cancelAuthenticationRequest();
    }
    // Nom d'utilisateur : clic = identité suivante (s'il y en a plusieurs)
    function nextIdentity() {
        if (!flow || identities.length < 2) return;
        identityIndex = (identityIndex + 1) % identities.length;
        flow.selectedIdentity = identities[identityIndex];
    }

    Connections {
        target: root.flow && !root.mock ? root.flow : null
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { root.shakeSerial += 1; }
    }
    onFlowChanged: {
        identityIndex = 0;
        pass.text = "";
    }
    onShakeSerialChanged: shakeAnim.restart()

    TahoeWindow {
        id: win
        shown: root.shown
        titleBar: false
        exclusiveKeyboard: true
        cardWidth: 290
        cardHeight: col.implicitHeight + 40

        Item {
            anchors.fill: parent
            transform: Translate { id: shake }
            Keys.onEscapePressed: root.cancel()

            Column {
                id: col
                x: 20
                y: 20
                width: parent.width - 40

                // Cadenas façon icône système (disque gris + cadenas)
                Item {
                    width: 64
                    height: 64
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 14
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.dark ? "#5b5e66" : "#f2f2f4" }
                            GradientStop { position: 1; color: Theme.dark ? "#3a3c42" : "#d6d7dc" }
                        }
                        border.width: 0.5
                        border.color: Qt.rgba(0, 0, 0, 0.15)
                    }
                    Symbol {
                        anchors.centerIn: parent
                        name: "lock.fill"
                        size: 34
                        color: Theme.dark ? "#e8e8ec" : "#5a5c63"
                    }
                }
                Item { width: 1; height: 14 }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.appName(root.flow?.actionId) + " veut effectuer des modifications."
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.label
                }
                Item { width: 1; height: 6 }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "Saisissez votre mot de passe pour autoriser cette action."
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.label
                }
                // Détail Polkit (ce qui est réellement demandé)
                Item { width: 1; height: (root.flow?.message ?? "") ? 6 : 0 }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    text: root.flow?.message ?? ""
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.labelSecondary
                }
                Item { width: 1; height: 14 }
                TahoeTextField {
                    width: parent.width
                    readOnly: true
                    text: root.userLabel
                    placeholder: "Nom d’utilisateur"
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.identities.length > 1
                        onClicked: root.nextIdentity()
                    }
                }
                Item { width: 1; height: 8 }
                TahoeTextField {
                    id: pass
                    width: parent.width
                    password: !(root.flow?.responseVisible ?? false)
                    placeholder: "Mot de passe"
                    focus: true
                    onAccepted: root.submit()
                }
                // Message d'erreur éventuel (PAM / Polkit)
                Text {
                    width: parent.width
                    topPadding: 6
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    text: root.flow?.supplementaryMessage ?? ""
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: (root.flow?.supplementaryIsError ?? false) ? Theme.red : Theme.labelSecondary
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
                        text: "OK"
                        isDefault: true
                        enabled: pass.text.length > 0
                        onClicked: root.submit()
                    }
                }
            }
        }

        // Secousse de la fenêtre sur échec
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shake; property: "x"; to: -12; duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: shake; property: "x"; to: 12; duration: 80; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shake; property: "x"; to: -8; duration: 70; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shake; property: "x"; to: 8; duration: 65; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shake; property: "x"; to: -3; duration: 60; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shake; property: "x"; to: 0; duration: 55; easing.type: Easing.OutQuad }
        }
    }

    // Banc de test : affiche un dialogue factice (aucune requête Polkit réelle)
    IpcHandler {
        target: "polkit-debug"
        enabled: Quickshell.env("QS_SESSION_DEBUG") === "1"
        function demo(): void {
            root.mock = {
                actionId: "org.freedesktop.systemd1.manage-units",
                message: "Authentification requise pour démarrer « sshd.service ».",
                identities: [],
                selectedIdentity: null,
                responseVisible: false,
                supplementaryMessage: "",
                supplementaryIsError: false,
                isCompleted: false,
                submit: function (v) { root.shakeSerial += 1; },
                cancelAuthenticationRequest: function () { root.mock = null; }
            };
        }
        function fail(): void { root.shakeSerial += 1; }
        function hide(): void { root.mock = null; }
        function registered(): bool { return agentLoader.item?.isRegistered ?? false; }
    }
}
