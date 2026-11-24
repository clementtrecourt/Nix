import QtQuick
import qs.common

// General > Sharing (Tahoe 26) : services de partage (état réel des services
// systemd : sshd, samba, avahi, cups…), nom d'hôte local.
PaneBase {
    id: root

    property var st: ({})
    ProcessText {
        running: true
        command: ["sh", "-c", 'for s in sshd samba-smbd smbd avahi-daemon cups wayvnc; do printf "%s=%s\\n" "$s" "$(systemctl is-active $s 2>/dev/null)"; done; ' +
                              'printf "user-wayvnc=%s\\n" "$(systemctl --user is-active wayvnc 2>/dev/null)"']
        onDone: (t) => {
            const o = {};
            for (const l of t.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim() === "active"; }
            root.st = o;
        }
    }

    SHeaderCard {
        pane: root.spec
        description: "Share files, your screen and more with other computers on your network. Sharing services are set in your NixOS configuration."
    }
    SSection { text: "Content & Media" }
    SGroup {
        SRow { title: "File Sharing"; symbol: "folder"; SSwitch { checked: !!(root.st["samba-smbd"] || root.st.smbd); enabledSwitch: false } }
        SRow { title: "Media Sharing"; symbol: "music.note"; SSwitch { checked: false; enabledSwitch: false } }
    }
    SSection { text: "Advanced" }
    SGroup {
        SRow { title: "Screen Sharing"; symbol: "display"; SSwitch { checked: !!(root.st.wayvnc || root.st["user-wayvnc"]); enabledSwitch: false } }
        SRow { title: "Remote Login"; symbol: "terminal"; SSwitch { checked: !!root.st.sshd; enabledSwitch: false } }
        SRow { title: "Printer Sharing"; symbol: "printer"; SSwitch { checked: !!root.st.cups; enabledSwitch: false } }
    }
    SGroup {
        SRow { title: "Local hostname"; detail: (Machine.info.host ?? "") + ".local" }
    }
}
