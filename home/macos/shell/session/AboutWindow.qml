import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// "À propos de ce Mac" (macOS Tahoe) : petite fenêtre sans titre, image de la
// machine (ici le logo NixOS), nom en grand, sous-titre gris, tableau
// libellé / valeur centré sur une gouttière, bouton "Plus d'infos…", mentions
// légales en bas. Ouverte par ShellState "about" (menu Pomme).
Scope {
    id: root

    property bool shown: false
    property var info: ({})

    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "about") {
                ShellState.close();
                root.shown = true;
                probe.running = true;
            }
        }
    }

    // Lit version, puce, mémoire, disque, nom d'hôte, modèle (clé=valeur)
    Process {
        id: probe
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "version=$VERSION_ID"
            echo "codename=$VERSION_CODENAME"
            echo "cpu=$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p' | head -1)"
            [ -z "$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p')" ] && echo "cpu=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)"
            echo "memkb=$(sed -n 's/^MemTotal:[[:space:]]*\\([0-9]*\\).*/\\1/p' /proc/meminfo)"
            echo "host=$(cat /proc/sys/kernel/hostname)"
            src=$(findmnt -no SOURCE / 2>/dev/null)
            echo "disk=$(lsblk -no LABEL "$src" 2>/dev/null | head -1)"
            echo "vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
            echo "product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
            echo "board=$(cat /sys/class/dmi/id/board_name 2>/dev/null)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0 && l.slice(i + 1).trim()) o[l.slice(0, i)] = l.slice(i + 1).trim();
                }
                root.info = o;
            }
        }
    }

    // "12th Gen Intel(R) Core(TM) i5-12600K" -> "Intel Core i5-12600K"
    // "AMD Ryzen 5 3600 6-Core Processor"    -> "AMD Ryzen 5 3600"
    function cleanCpu(s) {
        if (!s) return "—";
        return s.replace(/\((R|TM|tm|r)\)/g, "").replace(/^\d+(st|nd|rd|th) Gen /, "")
            .replace(/ CPU/, "").replace(/ @ .*/, "")
            .replace(/\s+\d+-Core( Processor)?/i, "").replace(/\s+(Processor|with Radeon.*)$/i, "").replace(/\s+/g, " ").trim();
    }
    // Mémoire installée (MemTotal arrondi au pair supérieur : 31,3 Gio -> 32 Go)
    function memory(kb) {
        if (!kb) return "—";
        const gib = Number(kb) / 1048576;
        return (gib < 3 ? Math.ceil(gib) : Math.ceil(gib / 2) * 2) + " Go";
    }
    function model() {
        const generic = /^(custom|to be filled|system product name|default string|none)/i;
        const p = root.info.product ?? "";
        if (p && !generic.test(p)) return ((root.info.vendor ?? "") + " " + p).trim();
        return root.info.board ?? "";
    }
    readonly property string codename: {
        const c = root.info.codename ?? "";
        return c ? c.charAt(0).toUpperCase() + c.slice(1) : "";
    }

    TahoeWindow {
        id: win
        shown: root.shown
        cardWidth: 280
        cardHeight: content.implicitHeight + 38 + 22
        minimizeEnabled: true
        zoomEnabled: false
        onCloseRequested: root.shown = false
        onMinimizeRequested: root.shown = false

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.shown = false
            Keys.onPressed: event => {
                if (event.key === Qt.Key_W && (event.modifiers & Qt.MetaModifier)) root.shown = false;
            }

            Column {
                id: content
                width: parent.width
                y: 4
                spacing: 0

                // "Image du Mac" -> logo NixOS nu (hicolor, sans le carré
                // arrondi que lui ajoutent les thèmes d'icônes façon macOS)
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 132
                    height: 132
                    sourceSize: Qt.size(264, 264)
                    source: "file:///run/current-system/sw/share/icons/hicolor/1024x1024/apps/nix-snowflake.png"
                    onStatusChanged: if (status === Image.Error) source = Quickshell.iconPath("nix-snowflake", "computer")
                    smooth: true
                    mipmap: true
                }
                Item { width: 1; height: 18 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NixOS"
                    font.family: Theme.fontDisplay
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    color: Theme.label
                }
                Item { width: 1; height: 2 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.model()
                    visible: text.length > 0
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.labelSecondary
                }
                Item { width: 1; height: 20 }

                // Tableau libellé (droite) | valeur (gauche) autour d'une gouttière
                Repeater {
                    model: [
                        ["Puce", root.cleanCpu(root.info.cpu)],
                        ["Mémoire", root.memory(root.info.memkb)],
                        ["Disque de démarrage", root.info.disk ?? "NixOS"],
                        ["Numéro de série", root.info.host ?? "—"],
                        // comme "macOS | Tahoe 26.1" : nom de code puis version
                        ["NixOS", ((root.codename ? root.codename + " " : "") + (root.info.version ?? "")).trim()]
                    ]
                    Item {
                        required property var modelData
                        width: content.width
                        height: 17
                        Text {
                            anchors.right: parent.horizontalCenter
                            anchors.rightMargin: 4
                            text: parent.modelData[0]
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.label
                        }
                        Text {
                            anchors.left: parent.horizontalCenter
                            anchors.leftMargin: 4
                            width: parent.width / 2 - 20
                            elide: Text.ElideRight
                            text: parent.modelData[1]
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.labelSecondary
                        }
                    }
                }

                Item { width: 1; height: 20 }
                TahoeButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitHeight: 24
                    fontSize: 13
                    text: "Plus d’infos…"
                    onClicked: {
                        root.shown = false;
                        Quickshell.execDetached(["sh", "-c", "gnome-control-center system 2>/dev/null || xdg-open https://nixos.org/"]);
                    }
                }
                Item { width: 1; height: 22 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Licence MIT"
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.labelSecondary
                }
                Item { width: 1; height: 3 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "™ et © 2003-" + new Date().getFullYear() + " NixOS Foundation\net contributeurs. Logiciel libre."
                    font.family: Theme.font
                    font.pixelSize: 10
                    lineHeight: 1.1
                    color: Theme.labelTertiary
                }
            }
        }
    }
}
