import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.common
import qs.services

// « About This Mac » (macOS Tahoe 26) : petite fenêtre sans titre (seule la
// pastille rouge est active), image de la machine (portable ou écran, l'écran
// affichant le fond d'écran courant), nom en gras 24 pt, sous-titre gris,
// tableau libellé | valeur autour d'une gouttière, bouton « More Info… »,
// mentions légales en bas. Ouverte par ShellState "about" (menu Apple).
//
// Mesures sur la capture Tahoe 26 de 512pixels (MacBook Air) : 280 pt de large,
// image en haut à 93 pt, ligne de base du nom à 254 pt, sous-titre à 270,5 pt,
// lignes du tableau tous les 16 pt dès 305,5 pt (11 pt), libellés finissant
// 7,5 pt avant le centre, valeurs 3,5 pt après, bouton 92 x 24 pt (rayon 6) à
// 376 pt, mentions (11 pt, tous les 14 pt) dès 425 pt. Le tableau suit le Mac
// Intel quand la machine est x86 (Processor, Graphics, Memory, Startup disk,
// Serial number) et le Mac Apple silicon sinon (Chip, Memory, Serial number).
Scope {
    id: root

    property bool shown: false
    property var info: ({})
    // Gris clair du sous-titre et des mentions (Tahoe clair : 170,180,185 sur blanc)
    readonly property color faint: Theme.dark ? Qt.rgba(1, 1, 1, 0.36) : Qt.rgba(0, 0, 0, 0.30)

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
            echo "arch=$(uname -m)"
            # Disque de démarrage : étiquette du système de fichiers racine
            # (racine en tmpfs, « impermanence » : celui de /nix)
            src=$(findmnt -no SOURCE / 2>/dev/null)
            case "$(findmnt -no FSTYPE / 2>/dev/null)" in tmpfs|overlay) src=$(findmnt -no SOURCE /nix 2>/dev/null);; esac
            src=\${src%%[*}
            echo "disk=$(lsblk -no LABEL "$src" 2>/dev/null | head -1)"
            echo "vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
            echo "product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
            echo "board=$(cat /sys/class/dmi/id/board_name 2>/dev/null)"
            echo "chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)"
            echo "biosdate=$(cat /sys/class/dmi/id/bios_date 2>/dev/null)"
            n=0
            lspci 2>/dev/null | grep -E 'VGA|3D controller|Display controller' | sed 's/^[^:]*: [^:]*: //' | while read -r l; do echo "gpu$n=$l"; n=$((n+1)); done
            [ -d /sys/class/power_supply ] && ls /sys/class/power_supply | grep -q '^BAT' && echo "battery=1"
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
    // Mémoire installée (MemTotal arrondi au pair supérieur : 31,1 Gio -> 32 GB)
    function memory(kb) {
        if (!kb) return "—";
        const gib = Number(kb) / 1048576;
        return (gib < 3 ? Math.ceil(gib) : Math.ceil(gib / 2) * 2) + " GB";
    }
    readonly property var _generic: /^(custom|to be filled|system product name|system manufacturer|default string|none|o\.e\.m\.|oem|not applicable|unknown)/i
    // Type de machine (DMI chassis_type, SMBIOS 3.x)
    readonly property string kind: {
        const c = Number(root.info.chassis ?? 0);
        if (root.info.battery || [8, 9, 10, 14, 31, 32].includes(c)) return "laptop";
        return "desktop";
    }
    // Nom (titre) : produit DMI s'il est parlant, sinon le type de machine
    readonly property string modelName: {
        const p = root.info.product ?? "";
        if (p && !_generic.test(p)) return p;
        const c = Number(root.info.chassis ?? 0);
        if (kind === "laptop") return "Laptop";
        if ([35, 36].includes(c)) return "Mini PC";
        return "Desktop PC";
    }
    // Sous-titre (comme « M1, 2020 ») : fabricant, carte mère, année du BIOS
    readonly property string subtitle: {
        const parts = [];
        const v = root.info.vendor ?? "", p = root.info.product ?? "";
        if (v && !_generic.test(v) && !(p && !_generic.test(p) && p.startsWith(v))) parts.push(v.replace(/,? (Inc|Co|Ltd|Corp|Corporation|Technology|GmbH)\.?.*$/i, ""));
        const b = root.info.board ?? "";
        if (b && !_generic.test(b) && (_generic.test(p) || !p)) parts.push(b);
        const y = (root.info.biosdate ?? "").match(/(19|20)\d\d/);
        if (y) parts.push(y[0]);
        return parts.join(", ");
    }
    // "Intel Corporation AlderLake-S GT1 [UHD Graphics 770]" -> "Intel UHD Graphics 770"
    // "NVIDIA Corporation AD104 [GeForce RTX 4070]"          -> "NVIDIA GeForce RTX 4070"
    function cleanGpu(l) {
        if (!l) return "";
        const vendor = /nvidia/i.test(l) ? "NVIDIA" : /amd|ati\b|advanced micro/i.test(l) ? "AMD" : /intel/i.test(l) ? "Intel" : "";
        const br = l.match(/\[([^\]]+)\][^\[]*$/);
        let name = br ? br[1] : l.replace(/^(Intel Corporation|NVIDIA Corporation|Advanced Micro Devices, Inc\.)\s*/, "");
        name = name.replace(/\s*\(rev [^)]*\)/, "").replace(/\s+\/.*$/, "");
        return name.startsWith(vendor) ? name : (vendor + " " + name).trim();
    }
    readonly property string gpu: {
        const all = Object.keys(root.info).filter(k => /^gpu\d+$/.test(k)).sort().map(k => root.info[k]);
        // Carte dédiée en priorité (NVIDIA / AMD), sinon la première
        const pick = all.find(l => /nvidia|amd|advanced micro/i.test(l)) ?? all[0] ?? "";
        return cleanGpu(pick);
    }
    readonly property bool x86: /^(x86_64|i[3-6]86)$/.test(root.info.arch ?? "x86_64")
    readonly property var rows: {
        const r = [];
        if (x86) {
            r.push(["Processor", root.cleanCpu(root.info.cpu)]);
            if (root.gpu) r.push(["Graphics", root.gpu]);
            r.push(["Memory", root.memory(root.info.memkb)]);
            r.push(["Startup disk", root.info.disk ?? "NixOS"]);
        } else {
            r.push(["Chip", root.cleanCpu(root.info.cpu)]);
            r.push(["Memory", root.memory(root.info.memkb)]);
        }
        r.push(["Serial number", root.info.host ?? "—"]);
        // comme « macOS | Tahoe 26.0 » : nom de code puis version
        r.push(["NixOS", ((root.codename ? root.codename + " " : "") + (root.info.version ?? "")).trim()]);
        return r;
    }
    readonly property string codename: {
        const c = root.info.codename ?? "";
        return c ? c.charAt(0).toUpperCase() + c.slice(1) : "";
    }

    TahoeWindow {
        id: win
        shown: root.shown
        cardWidth: 280
        // Bas : 33,5 pt sous la dernière ligne de base des mentions
        cardHeight: Math.round(more.y + 64 + 13.5 + 33.5)
        minimizeEnabled: false
        zoomEnabled: false
        onCloseRequested: root.shown = false

        Item {
            anchors.fill: parent
            anchors.topMargin: -win.titleBarHeight     // repère = haut de la fenêtre
            focus: true
            Keys.onEscapePressed: root.shown = false
            Keys.onPressed: event => {
                if (event.key === Qt.Key_W && (event.modifiers & Qt.MetaModifier)) root.shown = false;
            }

            // Image de la machine (le Mac dessiné par macOS) ; zone de 92 pt
            MacImage {
                id: machine
                anchors.horizontalCenter: parent.horizontalCenter
                y: 93
                laptop: root.kind === "laptop"
            }

            // Positions absolues (lignes de base mesurées, repère = haut de fenêtre)
            Text {
                id: name
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.baseline: parent.top
                anchors.baselineOffset: 254
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.modelName
                font.family: Theme.fontDisplay
                font.pixelSize: 24
                font.weight: Font.Bold
                // Gris très foncé (#1D1D1F mesuré sur About This Mac), pas noir
                color: Theme.dark ? "#F5F5F7" : "#1D1D1F"
            }
            Text {
                id: sub
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.baseline: parent.top
                anchors.baselineOffset: 270.5
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.subtitle
                font.family: Theme.font
                font.pixelSize: 11
                color: root.faint
            }

            // Tableau : lignes de base tous les 16 pt dès 305,5 pt
            Column {
                id: table
                y: 305.5 - 12
                width: parent.width
                Repeater {
                    model: root.rows
                    Item {
                        required property var modelData
                        width: table.width
                        height: 16
                        Text {
                            anchors.right: parent.horizontalCenter
                            anchors.rightMargin: 7.5
                            anchors.baseline: parent.top
                            anchors.baselineOffset: 12
                            text: parent.modelData[0]
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.label
                        }
                        Text {
                            anchors.left: parent.horizontalCenter
                            anchors.leftMargin: 3.5
                            anchors.baseline: parent.top
                            anchors.baselineOffset: 12
                            width: parent.width / 2 - 16
                            elide: Text.ElideRight
                            text: parent.modelData[1]
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.labelSecondary
                        }
                    }
                }
            }

            // Bouton : haut 22,5 pt sous la dernière ligne de base
            TahoeButton {
                id: more
                anchors.horizontalCenter: parent.horizontalCenter
                y: table.y + table.height - 4 + 22.5
                implicitHeight: 24
                width: 92
                radius: 6
                text: "More Info…"
                onClicked: {
                    root.shown = false;
                    Quickshell.execDetached(["sh", "-c", "gnome-control-center system 2>/dev/null || gnome-control-center info-overview 2>/dev/null || xdg-open https://nixos.org/"]);
                }
            }

            // Mentions : lignes de base à 49, 64 et 77,5 pt sous le haut du bouton
            Text {
                id: link
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.baseline: more.top
                anchors.baselineOffset: 49
                text: "License Agreement"
                font.family: Theme.font
                font.pixelSize: 11
                font.underline: true
                color: linkMouse.pressed ? Theme.labelSecondary : Theme.labelTertiary
                MouseArea {
                    id: linkMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.shown = false;
                        Qt.openUrlExternally("https://github.com/NixOS/nixpkgs/blob/master/COPYING");
                    }
                }
            }
            Text {
                id: legal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.baseline: more.top
                anchors.baselineOffset: 64
                horizontalAlignment: Text.AlignHCenter
                text: "™ and © 2003-" + new Date().getFullYear() + " NixOS Foundation\nand contributors."
                font.family: Theme.font
                font.pixelSize: 11
                lineHeightMode: Text.FixedHeight
                lineHeight: 13.5
                color: root.faint
            }
        }
    }

    // Image de la machine façon macOS : MacBook (écran + base alu) ou écran de
    // bureau (Studio Display : dalle, bord alu, pied). La dalle montre le fond
    // d'écran courant, comme les images de Mac d'About This Mac.
    component MacImage: Item {
        id: mac
        property bool laptop: false
        width: 152
        height: 92

        // Écran (couvercle / dalle)
        Rectangle {
            id: lid
            anchors.horizontalCenter: parent.horizontalCenter
            y: mac.laptop ? 1 : 0
            width: mac.laptop ? 118 : 132
            height: mac.laptop ? 78 : 76
            radius: mac.laptop ? 5 : 3
            // Bord aluminium (fin liseré) + cadre noir
            color: mac.laptop ? "#2a2a2c" : "#c9cacd"
            Rectangle {
                anchors.fill: parent
                anchors.margins: mac.laptop ? 0.75 : 1
                radius: parent.radius - 0.5
                color: "#0d0d0e"
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.leftMargin: mac.laptop ? 3.5 : 3
                    anchors.rightMargin: mac.laptop ? 3.5 : 3
                    anchors.topMargin: mac.laptop ? 4 : 3
                    anchors.bottomMargin: mac.laptop ? 5 : 3
                    radius: mac.laptop ? 1.5 : 0.5
                    color: "black"
                    WallpaperView {
                        anchors.fill: parent
                        decodeSize: Qt.size(260, 160)
                    }
                }
            }
        }

        // Portable : base aluminium (lèvre claire, dessous plus sombre, encoche)
        Item {
            visible: mac.laptop
            anchors.horizontalCenter: parent.horizontalCenter
            y: lid.y + lid.height - 0.5
            width: 152
            height: 6
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e9eaec" }
                    GradientStop { position: 0.5; color: "#c7c8cb" }
                    GradientStop { position: 1; color: "#8e8f93" }
                }
            }
            // Encoche d'ouverture
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 22
                height: 1.6
                radius: 0.8
                color: "#9fa0a4"
            }
            // Ombre au sol
            Rectangle {
                y: 4
                x: 6
                width: parent.width - 12
                height: 2
                radius: 1
                color: Qt.rgba(0, 0, 0, 0.18)
            }
        }

        // Écran de bureau : pied aluminium (col + plateau)
        Item {
            visible: !mac.laptop
            anchors.horizontalCenter: parent.horizontalCenter
            y: lid.height - 1
            width: 52
            height: mac.height - lid.height + 1
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 30
                height: parent.height - 2.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#a9aaae" }
                    GradientStop { position: 0.5; color: "#d6d7da" }
                    GradientStop { position: 1; color: "#a3a4a8" }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 3
                radius: 1.5
                gradient: Gradient {
                    GradientStop { position: 0; color: "#dcdde0" }
                    GradientStop { position: 1; color: "#9c9da1" }
                }
            }
        }
    }
}
