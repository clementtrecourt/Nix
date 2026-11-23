import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import qs.services

// Écran de verrouillage macOS Tahoe (ext-session-lock) + authentification PAM.
//
// Déclencheurs : raccourci global "macos:lock" (Ctrl+Cmd+Q), panneau ShellState
// "lock", IPC `quickshell -c macos ipc call lock lock`.
// Aucune IPC ne permet de déverrouiller : seul PAM le peut.
Scope {
    id: root

    // Saisie partagée entre les écrans (on tape sur n'importe lequel)
    property string password: ""
    property bool authenticating: false
    property int failures: 0
    property string errorText: ""
    // Incrémenté à chaque échec : les surfaces jouent la secousse
    property int shakeSerial: 0
    // Incrémenté au succès : les surfaces jouent la sortie avant déverrouillage
    property bool unlocking: false

    readonly property string userName: Quickshell.env("USER") ?? ""
    property string fullName: userName.length ? userName.charAt(0).toUpperCase() + userName.slice(1) : ""
    readonly property string facePath: Quickshell.env("HOME") + "/.face"

    function lock() {
        if (sessionLock.locked) return;
        password = "";
        errorText = "";
        failures = 0;
        unlocking = false;
        sessionLock.locked = true;
    }

    function submit() {
        if (authenticating || unlocking || password.length === 0) return;
        authenticating = true;
        errorText = "";
        if (!pam.start()) {
            authenticating = false;
            errorText = "Authentification indisponible";
        }
    }

    // Nom complet (champ GECOS) comme macOS l'affiche sous l'avatar
    Process {
        running: true
        command: ["getent", "passwd", root.userName]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0].trim();
                if (gecos) root.fullName = gecos;
            }
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: root.userName

        onPamMessage: {
            if (responseRequired) respond(root.password);
            else if (messageIsError) root.errorText = message;
        }
        onCompleted: result => {
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.unlocking = true;
                unlockDelay.restart();
            } else {
                root.failures += 1;
                root.password = "";
                root.shakeSerial += 1;
                if (result === PamResult.MaxTries) root.errorText = "Trop de tentatives";
            }
        }
        onError: err => {
            root.authenticating = false;
            root.password = "";
            root.shakeSerial += 1;
            root.errorText = PamError.toString(err);
        }
    }

    // Laisse jouer l'animation de sortie avant de rendre la session
    Timer {
        id: unlockDelay
        interval: 260
        onTriggered: {
            sessionLock.locked = false;
            root.password = "";
            root.unlocking = false;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surf
            color: "black"
            LockSurface {
                anchors.fill: parent
                lockRoot: root
                screen: surf.screen
            }
        }
    }

    GlobalShortcut {
        appid: "macos"
        name: "lock"
        description: "Verrouiller l’écran"
        onPressed: root.lock()
    }

    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "lock") {
                ShellState.close();
                root.lock();
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return sessionLock.locked; }
    }

    // Banc de test uniquement (QS_SESSION_DEBUG=1) : simule une saisie.
    IpcHandler {
        target: "lock-debug"
        enabled: Quickshell.env("QS_SESSION_DEBUG") === "1"
        function type(text: string): void { root.password = text; }
        function submit(): void { root.submit(); }
    }
}
