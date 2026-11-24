import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// General > Login Items & Extensions (Tahoe 26) : « Open at Login » (entrées
// ~/.config/autostart), « Allow in the Background » (services systemd
// utilisateur actifs).
PaneBase {
    id: root

    property var autostart: []
    property var services: []
    ProcessText {
        running: true
        command: ["sh", "-c", 'for f in "${XDG_CONFIG_HOME:-$HOME/.config}"/autostart/*.desktop; do [ -e "$f" ] || continue; printf "A\\t%s\\t%s\\n" "$(basename "$f" .desktop)" "$(sed -n "s/^Name=//p" "$f" | head -1)"; done; ' +
                              'systemctl --user list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk \'{print "S\\t"$1}\'']
        onDone: (t) => {
            const a = [], s = [];
            for (const l of t.split("\n")) {
                const f = l.split("\t");
                if (f[0] === "A") a.push({ id: f[1], name: f[2] || f[1] });
                else if (f[0] === "S" && f[1]) s.push(f[1].replace(/\.service$/, ""));
            }
            root.autostart = a;
            root.services = s;
        }
    }

    SHeaderCard {
        pane: root.spec
        description: "Login items open automatically when you log in. Background items run in the background."
    }
    SSection { text: "Open at Login" }
    SGroup {
        Repeater {
            model: root.autostart
            SRow {
                required property var modelData
                title: modelData.name
                iconSource: Quickshell.iconPath(DesktopEntries.byId(modelData.id)?.icon ?? "application-x-executable", "application-x-executable")
            }
        }
        SRow { visible: root.autostart.length === 0; title: "No items"; dimmed: true }
    }
    SSection { text: "Allow in the Background" }
    SGroup {
        Repeater {
            model: root.services
            SRow {
                required property string modelData
                title: modelData
                subtitle: "systemd user service"
                symbol: "gearshape"
                SSwitch { checked: true; enabledSwitch: false }
            }
        }
    }
}
