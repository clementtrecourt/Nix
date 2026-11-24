import QtQuick
import qs.common

// General > Software Update (Tahoe 26) : état du système (génération NixOS
// courante, date de construction), mises à jour automatiques (déclaratives).
PaneBase {
    id: root

    property string gen: ""
    property string built: ""
    ProcessText {
        running: true
        command: ["sh", "-c", 'p=$(readlink -f /run/current-system); printf "%s\\n%s\\n" "$(basename "$p" | cut -d- -f2-)" "$(date -r "$p" "+%B %-d, %Y at %-I:%M %p" 2>/dev/null)"']
        onDone: (t) => { const l = t.trim().split("\n"); root.gen = l[0] ?? ""; root.built = l[1] ?? ""; }
    }

    SHeaderCard {
        pane: root.spec
        description: "Your Mac is up to date — NixOS " + (Machine.info.version ?? "") + "\nThe system is updated by rebuilding your NixOS configuration."
    }
    SGroup {
        SRow { title: "Current version"; detail: "NixOS " + Machine.codename + " " + (Machine.info.version ?? "") }
        SRow { title: "Build"; detail: Machine.info.build || root.gen || "—" }
        SRow { title: "Installed"; detail: root.built || "—" }
        SRow { title: "Kernel"; detail: Machine.info.kernel ?? "—" }
    }
    SGroup {
        SRow {
            title: "Automatic updates"
            subtitle: "Updates are applied declaratively when the configuration is rebuilt."
            detail: "Managed by NixOS"
        }
    }
}
