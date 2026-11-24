pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Comptes du système (getent passwd, uid ≥ 1000) : utilisateur courant (nom
// complet GECOS, avatar ~/.face) et autres comptes, pour la carte de la barre
// latérale, Users & Groups et le panneau du compte.
Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER") ?? ""
    readonly property string home: Quickshell.env("HOME") ?? ""
    property string fullName: userName.length ? userName.charAt(0).toUpperCase() + userName.slice(1) : ""
    property string faceUrl: ""
    property string shell: ""
    property var users: []          // [{ name, full, uid, home, admin }]
    property var groups: []

    function refresh() { probe.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: probe
        command: ["sh", "-c", 'getent passwd | awk -F: \'$3>=1000 && $3<60000 {print}\'; echo "--"; ' +
                              'getent group wheel | cut -d: -f4; echo "--"; id -Gn; echo "--"; [ -r "$HOME/.face" ] && echo face; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("--\n");
                const admins = (parts[1] ?? "").trim().split(",");
                const l = [];
                for (const line of (parts[0] ?? "").split("\n")) {
                    const f = line.split(":");
                    if (f.length < 7) continue;
                    // Comptes de service (nixbld*, shells nologin) : non listés
                    if (/^nixbld/.test(f[0]) || /nologin|false$/.test(f[6])) continue;
                    const full = (f[4] ?? "").split(",")[0];
                    l.push({ name: f[0], full: full || (f[0].charAt(0).toUpperCase() + f[0].slice(1)), uid: Number(f[2]), home: f[5], shell: f[6], admin: admins.includes(f[0]) });
                    if (f[0] === root.userName) {
                        if (full) root.fullName = full;
                        root.shell = f[6];
                    }
                }
                root.users = l;
                root.groups = (parts[2] ?? "").trim().split(/\s+/).filter(g => g);
                root.faceUrl = (parts[3] ?? "").indexOf("face") >= 0 ? "file://" + root.home + "/.face" : "";
            }
        }
    }
}
