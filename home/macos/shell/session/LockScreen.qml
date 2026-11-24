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
    // Facteur de ralenti des animations (banc de test uniquement)
    property real slowmo: 1

    readonly property string userName: Quickshell.env("USER") ?? ""
    property string fullName: userName.length ? userName.charAt(0).toUpperCase() + userName.slice(1) : ""
    readonly property string facePath: Quickshell.env("HOME") + "/.face"
    // URL de l'avatar, seulement si ~/.face existe (sinon monogramme, sans
    // avertissement "Cannot open" de l'Image)
    property string faceSource: ""

    // Source de saisie active (coin supérieur droit, comme macOS : « U.S. »,
    // « French »…), lue dans Hyprland puis suivie par l'événement activelayout.
    property string layoutName: ""
    function layoutLabel(name) {
        const n = name ?? "";
        if (/^English \(US\)|^US\b/.test(n)) return "U.S.";
        if (/^English \(UK\)/.test(n)) return "British";
        // xkb « French » = AZERTY PC ; « French (Macintosh) » = AZERTY Mac
        if (/^French \(Macintosh\)/.test(n)) return "French";
        if (/^French/.test(n)) return "French - PC";
        if (/^German/.test(n)) return "German";
        if (/^Spanish/.test(n)) return "Spanish";
        if (/^Italian/.test(n)) return "Italian";
        if (/^Belgian/.test(n)) return "Belgian";
        if (/^Swiss/.test(n)) return "Swiss French";
        // Nom inconnu : partie avant « - » ou « ( », pour rester court
        return n.split(/ - | \(/)[0];
    }

    function lock() {
        if (sessionLock.locked) return;
        faceProbe.running = true;
        layoutProbe.running = true;
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
            errorText = "Authentication unavailable";
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

    // ~/.face lisible ? (relu à chaque verrouillage : l'avatar peut changer)
    Process {
        id: faceProbe
        running: true
        command: ["test", "-r", root.facePath]
        onExited: code => root.faceSource = code === 0 ? "file://" + root.facePath : ""
    }

    // Disposition du clavier principal (hyprctl devices -j)
    Process {
        id: layoutProbe
        running: true
        // hyprctl du PATH, sinon celui livré à côté de l'exécutable Hyprland
        // en cours (pid dans hyprland.lock) : utile hors session installée.
        command: ["sh", "-c",
            'h=$(command -v hyprctl) || h="$(dirname "$(readlink -f /proc/$(head -n1 "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock")/exe)")/hyprctl"; ' +
            '[ -x "$h" ] && exec "$h" devices -j']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    if (kb) root.layoutName = root.layoutLabel(kb.active_keymap);
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            // données : "<clavier>,<disposition>" (le nom du clavier peut contenir des virgules)
            const d = event.data;
            const i = d.lastIndexOf(",");
            if (i >= 0) root.layoutName = root.layoutLabel(d.slice(i + 1));
        }
    }

    // Service PAM : "quickshell" s'il est déclaré (security.pam.services.quickshell,
    // pile d'authentification dédiée au verrouillage), sinon "login".
    property string pamService: "login"
    Process {
        running: true
        command: ["test", "-r", "/etc/pam.d/quickshell"]
        onExited: code => root.pamService = code === 0 ? "quickshell" : "login"
    }

    PamContext {
        id: pam
        config: root.pamService
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
                if (result === PamResult.MaxTries) root.errorText = "Too many attempts. Try again later.";
            }
        }
        // Erreur PAM (module refusé, service absent…) : comme un échec, mais
        // avec un message, sinon l'utilisateur ne comprendrait pas le refus.
        onError: err => {
            root.authenticating = false;
            root.password = "";
            root.shakeSerial += 1;
            root.errorText = "Unable to verify password";
            console.info("lock: erreur PAM", PamError.toString(err));
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
        description: "Lock Screen"
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
        function shake(): void { root.shakeSerial += 1; }
        function slowmo(f: real): void { root.slowmo = f; }
        // PAM du bac à sable ne peut pas valider : déverrouillage de test
        function unlock(): void { root.unlocking = true; unlockDelay.restart(); }
    }
}
