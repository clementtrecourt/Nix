pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Informations machine réelles (General > About, Storage, Sharing) : version
// NixOS, processeur, mémoire, graphismes, disque, nom d'hôte, modèle DMI,
// écrans, espace disque. Mêmes règles de présentation que About This Mac
// (session/AboutWindow).
Singleton {
    id: root

    property var info: ({})
    property var disk: ({ total: 0, used: 0, avail: 0, home: -1, nix: -1 })
    property bool loaded: false

    function refresh() { probe.running = true; df.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: probe
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "version=$VERSION_ID"
            echo "codename=$VERSION_CODENAME"
            echo "build=$BUILD_ID"
            echo "cpu=$(LC_ALL=C lscpu 2>/dev/null | sed -n 's/^Model name:[[:space:]]*//p' | head -1)"
            echo "cores=$(nproc 2>/dev/null)"
            echo "memkb=$(sed -n 's/^MemTotal:[[:space:]]*\\([0-9]*\\).*/\\1/p' /proc/meminfo)"
            echo "host=$(cat /proc/sys/kernel/hostname)"
            echo "pretty=$(hostnamectl --pretty 2>/dev/null)"
            echo "arch=$(uname -m)"
            echo "kernel=$(uname -r)"
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
            ls /sys/class/power_supply 2>/dev/null | grep -q '^BAT' && echo "battery=1"
            true
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0) o[l.slice(0, i)] = l.slice(i + 1);
                }
                root.info = o;
                root.loaded = true;
            }
        }
    }
    // Espace disque : racine (ou /nix si la racine est en mémoire)
    Process {
        id: df
        command: ["sh", "-c", 't=$(findmnt -no FSTYPE / 2>/dev/null); m=/; case "$t" in tmpfs|overlay) m=/nix;; esac; ' +
                              'df -B1 --output=size,used,avail "$m" | tail -1']
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).map(Number);
                if (f.length >= 3) root.disk = Object.assign({}, root.disk, { total: f[0], used: f[1], avail: f[2] });
            }
        }
    }
    // Taille du dossier personnel et du store (calcul lent, à la demande)
    function measure() { if (!du.running) du.running = true; }
    Process {
        id: du
        command: ["sh", "-c", 'printf "home=%s\\n" "$(timeout 20 du -sxb "$HOME" 2>/dev/null | cut -f1)"; ' +
                              'printf "nix=%s\\n" "$(timeout 20 du -sxb /nix/store 2>/dev/null | cut -f1)"']
        stdout: StdioCollector {
            onStreamFinished: {
                const d = Object.assign({}, root.disk);
                for (const l of text.split("\n")) {
                    const [k, v] = l.split("=");
                    if (k && v) d[k] = Number(v);
                }
                root.disk = d;
            }
        }
    }

    // ---- Présentation (comme About This Mac) ----
    readonly property bool laptop: !!info.battery || [8, 9, 10, 14, 31, 32].includes(Number(info.chassis ?? 0))
    readonly property var _generic: /^(custom|to be filled|system product name|system manufacturer|default string|none|o\.e\.m\.|oem|not applicable|unknown)/i
    readonly property string modelName: {
        const p = info.product ?? "";
        if (p && !_generic.test(p)) return p;
        const c = Number(info.chassis ?? 0);
        if (laptop) return "Laptop";
        if ([35, 36].includes(c)) return "Mini PC";
        return "Desktop PC";
    }
    readonly property string subtitle: {
        const parts = [];
        const v = info.vendor ?? "", p = info.product ?? "";
        if (v && !_generic.test(v) && !(p && !_generic.test(p) && p.startsWith(v))) parts.push(v.replace(/,? (Inc|Co|Ltd|Corp|Corporation|Technology|GmbH)\.?.*$/i, ""));
        const b = info.board ?? "";
        if (b && !_generic.test(b) && (_generic.test(p) || !p)) parts.push(b);
        const y = (info.biosdate ?? "").match(/(19|20)\d\d/);
        if (y) parts.push(y[0]);
        return parts.join(", ");
    }
    readonly property string cpu: {
        const s = info.cpu ?? "";
        if (!s) return "—";
        return s.replace(/\((R|TM|tm|r)\)/g, "").replace(/^\d+(st|nd|rd|th) Gen /, "").replace(/ CPU/, "").replace(/ @ .*/, "")
                .replace(/\s+\d+-Core( Processor)?/i, "").replace(/\s+(Processor|with Radeon.*)$/i, "").replace(/\s+/g, " ").trim();
    }
    readonly property string memory: {
        const kb = Number(info.memkb ?? 0);
        if (!kb) return "—";
        const gib = kb / 1048576;
        return (gib < 3 ? Math.ceil(gib) : Math.ceil(gib / 2) * 2) + " GB";
    }
    readonly property string gpu: {
        const all = Object.keys(info).filter(k => /^gpu\d+$/.test(k)).sort().map(k => info[k]);
        const l = all.find(x => /nvidia|amd|advanced micro/i.test(x)) ?? all[0] ?? "";
        if (!l) return "";
        const vendor = /nvidia/i.test(l) ? "NVIDIA" : /amd|ati\b|advanced micro/i.test(l) ? "AMD" : /intel/i.test(l) ? "Intel" : "";
        const br = l.match(/\[([^\]]+)\][^\[]*$/);
        let name = br ? br[1] : l.replace(/^(Intel Corporation|NVIDIA Corporation|Advanced Micro Devices, Inc\.)\s*/, "");
        name = name.replace(/\s*\(rev [^)]*\)/, "").replace(/\s+\/.*$/, "");
        return name.startsWith(vendor) ? name : (vendor + " " + name).trim();
    }
    readonly property bool x86: /^(x86_64|i[3-6]86)$/.test(info.arch ?? "x86_64")
    readonly property string codename: { const c = info.codename ?? ""; return c ? c.charAt(0).toUpperCase() + c.slice(1) : ""; }
    readonly property string hostName: info.pretty || info.host || ""
    readonly property string diskName: info.disk || "NixOS"

    // « 12.3 GB », « 512 KB » (unités décimales, comme macOS)
    function size(b) {
        if (b === undefined || b < 0) return "—";
        const u = ["bytes", "KB", "MB", "GB", "TB"];
        let i = 0, v = b;
        while (v >= 1000 && i < u.length - 1) { v /= 1000; ++i; }
        return (i === 0 ? v : v < 10 ? v.toFixed(2) : v < 100 ? v.toFixed(1) : Math.round(v)) + " " + u[i];
    }
}
