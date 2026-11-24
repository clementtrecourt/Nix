import QtQuick
import Quickshell
import qs.common

// Panneaux sans équivalent fonctionnel sur ce bureau, affichés comme Tahoe
// mais grisés (Accessibility, Apple Intelligence & Siri, Spotlight, Screen
// Time, Privacy & Security, Login Password, Internet Accounts, Game Center,
// iCloud, Wallet & Apple Pay, Printers & Scanners). Les éléments qui ont un
// équivalent réel restent actifs (imprimantes CUPS, FileVault = LUKS,
// changement de mot de passe, réglages du Wi‑Fi…).
PaneBase {
    id: root

    property var printers: []
    property bool luks: false
    ProcessText {
        running: true
        command: ["sh", "-c", "lpstat -p 2>/dev/null | awk '/^printer/{print $2}'; echo --; lsblk -no TYPE 2>/dev/null | grep -qx crypt && echo luks; true"]
        onDone: (t) => {
            const p = t.split("--\n");
            root.printers = (p[0] ?? "").split("\n").filter(x => x);
            root.luks = (p[1] ?? "").indexOf("luks") >= 0;
        }
    }

    // r : { t: titre, s?: sous-titre, d?: valeur, sw?: interrupteur, c?: chevron, p?: id de panneau (icône), sym?: symbole, act?: action }
    readonly property var tables: ({
        accessibility: {
            desc: "Personalize Mac in ways that work best for you with accessibility features for vision, hearing, motor, speech, and cognition.",
            sections: [
                { h: "Vision", rows: [{ t: "VoiceOver", sym: "speaker.wave.2.fill", c: true }, { t: "Zoom", sym: "plus.magnifyingglass", c: true }, { t: "Hover Text", sym: "character.textbox", c: true }, { t: "Display", sym: "display", c: true }, { t: "Motion", sym: "sparkles", c: true }, { t: "Spoken Content", sym: "speaker.wave.3.fill", c: true }, { t: "Descriptions", sym: "text.alignleft", c: true }] },
                { h: "Hearing", rows: [{ t: "Hearing Devices", sym: "headphones", c: true }, { t: "Audio", sym: "speaker.fill", c: true }, { t: "Captions", sym: "film", c: true }] },
                { h: "Motor", rows: [{ t: "Voice Control", sym: "mic.fill", c: true }, { t: "Keyboard", sym: "keyboard", c: true, act: () => Nav.go("keyboard") }, { t: "Pointer Control", sym: "computermouse", c: true, act: () => Nav.go(Nav.hasTouchpad ? "trackpad" : "mouse") }, { t: "Switch Control", sym: "switch.2", c: true }] },
                { h: "General", rows: [{ t: "Siri", sym: "apple.intelligence", c: true }, { t: "Shortcut", sym: "command", c: true }] }
            ]
        },
        intelligence: {
            desc: "Apple Intelligence and Siri are not available on this computer.",
            sections: [{ rows: [{ t: "Apple Intelligence", sw: false }, { t: "Siri", sw: false }, { t: "Keyboard shortcut", d: "Press Either Command Key Twice" }, { t: "Language", d: "English (United States)" }, { t: "Voice", d: "American (Voice 4)" }] }]
        },
        spotlight: {
            desc: "Spotlight helps you quickly find things on your computer and shows suggestions from the internet, Music, App Store, movie showtimes, locations nearby, and more.",
            sections: [
                { rows: [{ t: "Show Related Content", s: "Allow content from Apple partners to be shown when searching or when looking up text or objects and photos.", sw: false }] },
                { rows: [{ t: "Spotlight Search History", d: "", btn: "Delete Search History…" }] },
                { h: "Results from Apps", rows: [{ t: "Applications", sw: true }, { t: "Calculator", sw: true }, { t: "Documents", sw: true }, { t: "Folders", sw: true }, { t: "Images", sw: true }, { t: "PDF Documents", sw: true }, { t: "System Settings", sw: true }] }
            ]
        },
        screentime: {
            desc: "Get insights about your screen time and set limits for what you want to manage.",
            sections: [
                { rows: [{ t: "App & Website Activity", s: "Turn On App & Website Activity…", c: true }, { t: "Notifications", c: true }, { t: "Pickups", c: true }] },
                { h: "Limit Usage", rows: [{ t: "Downtime", c: true }, { t: "App Limits", c: true }, { t: "Always Allowed", c: true }] },
                { rows: [{ t: "Share across devices", sw: false }, { t: "Lock Screen Time Settings", sw: false }] }
            ]
        },
        privacy: {
            desc: "",
            sections: [
                { h: "Privacy", rows: [{ t: "Location Services", sym: "location", c: true, d: "Off" }, { t: "Contacts", sym: "person.crop.circle", c: true }, { t: "Calendars", sym: "calendar.clock", c: true }, { t: "Photos", sym: "photo", c: true }, { t: "Microphone", sym: "mic.fill", c: true }, { t: "Camera", sym: "camera.viewfinder", c: true }, { t: "Screen & System Audio Recording", sym: "rectangle.dashed.badge.record", c: true }, { t: "Full Disk Access", sym: "internaldrive", c: true }] },
                { h: "Security", rows: [{ t: "Allow applications from", d: "App Store & Known Developers" }, { t: "FileVault", sym: "lock.fill", live: "filevault", c: true }, { t: "Firewall", sym: "checkmark.shield", c: true, act: () => Nav.go("network") }] }
            ]
        },
        password: {
            desc: "Change the password you use to log in to this Mac and unlock it.",
            sections: [{ rows: [{ t: "Login Password", d: "", btn: "Change…", act: () => Quickshell.execDetached(["kitty", "--title", "Change Password", "-e", "passwd"]) }, { t: "Use your Apple Watch to unlock your applications and your Mac", sw: false }] }]
        },
        accounts: {
            desc: "Manage the accounts you use with Mail, Contacts, Calendar, and other apps.",
            sections: [{ rows: [{ t: "No accounts", d: "" }] }]
        },
        gamecenter: {
            desc: "Game Center is not available on this computer.",
            sections: [{ rows: [{ t: "Game Center", sw: false }] }]
        },
        icloud: {
            desc: "Store your photos, files, and backups securely in iCloud and keep them up to date across your devices.",
            sections: [{ rows: [{ t: "iCloud Drive", d: "Off", c: true }, { t: "Photos", d: "Off", c: true }, { t: "Passwords", d: "Off", c: true }, { t: "Mail", d: "Off", c: true }] }]
        },
        wallet: {
            desc: "Add cards to make secure purchases in apps and on the web with Apple Pay.",
            sections: [{ rows: [{ t: "Add Card…", d: "" }, { t: "Default card", d: "None" }] }]
        }
    })
    readonly property var d: tables[paneId] ?? null

    SHeaderCard {
        visible: !!root.d && root.d.desc !== ""
        pane: root.spec
        description: root.d?.desc ?? ""
    }

    // ---- Printers & Scanners (CUPS) ----
    SGroup {
        visible: root.paneId === "printers"
        Repeater {
            model: root.printers
            SRow { required property string modelData; title: modelData.replace(/_/g, " "); symbol: "printer.fill"; symbolColor: SStyle.label; minHeight: 42 }
        }
        SRow { visible: root.printers.length === 0; title: "No printers are available."; dimmed: true }
    }
    Item {
        visible: root.paneId === "printers"
        width: parent.width
        height: 28
        SButton {
            anchors.right: parent.right; y: 2
            text: "Add Printer, Scanner, or Fax…"
            onClicked: Quickshell.execDetached(["sh", "-c", "command -v system-config-printer >/dev/null && exec system-config-printer || exec xdg-open http://localhost:631/admin"])
        }
    }

    Repeater {
        model: root.d?.sections ?? []
        Column {
            id: sec
            required property var modelData
            width: root.width
            spacing: SStyle.groupSpacing
            SSection { visible: !!sec.modelData.h; text: sec.modelData.h ?? "" }
            SGroup {
                Repeater {
                    model: sec.modelData.rows
                    SRow {
                        required property var modelData
                        readonly property bool active: !!modelData.act
                        title: modelData.t
                        subtitle: modelData.s ?? ""
                        symbol: modelData.sym ?? ""
                        symbolColor: SStyle.accent
                        detail: modelData.live === "filevault" ? (root.luks ? "On" : "Off") : (modelData.d ?? "")
                        chevron: !!modelData.c
                        clickable: active
                        dimmed: !active && !modelData.live
                        onClicked: modelData.act()
                        SSwitch { visible: modelData.sw !== undefined; checked: !!modelData.sw; enabledSwitch: false }
                        SButton { visible: !!modelData.btn; text: modelData.btn ?? ""; enabledButton: !!modelData.act; onClicked: modelData.act() }
                    }
                }
            }
        }
    }
}
