pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Navigation de Réglages Système : fenêtre ouverte, panneau courant,
// historique ‹ ›, catalogue des panneaux (ordre et libellés exacts de la barre
// latérale de Tahoe 26, d'après les captures Apple mh15217 / mchlp3013 et
// MacStories), recherche.
Singleton {
    id: root

    property bool shown: false
    // Fenêtre ouverte (SettingsWindow), null sinon
    property var window: null
    property string pane: "appearance"
    property var backStack: []
    property var fwdStack: []
    property string search: ""
    // Demande de mise au premier plan (fenêtre déjà ouverte)
    signal raiseRequested()

    // ---- Matériel détecté (panneaux conditionnels) ----
    property bool hasBattery: false
    property bool hasTouchpad: false
    property bool hasMouse: true
    Process {
        running: true
        command: ["sh", "-c", 'ls /sys/class/power_supply 2>/dev/null | grep -q "^BAT" && echo battery; ' +
                              'hyprctl devices -j 2>/dev/null | grep -qi "touchpad\\|trackpad" && echo touchpad; true']
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasBattery = text.indexOf("battery") >= 0;
                root.hasTouchpad = text.indexOf("touchpad") >= 0;
            }
        }
    }

    // ---- Catalogue ----
    // icon : symbole blanc sur pastille ; c1 -> c2 : dégradé vertical de la pastille.
    // file : composant du panneau (Pane<file>.qml) ; parent : panneau parent
    // (sous-panneaux de General) ; kw : mots-clés de recherche.
    readonly property var blue: ["#40A0FF", "#0A6FEF"]
    readonly property var gray: ["#A9A9AE", "#8A8A90"]
    readonly property var black: ["#3A3A3C", "#0C0C0D"]
    readonly property var catalog: [
        { id: "wifi", name: "Wi‑Fi", icon: "wifi", c: blue, group: 1, file: "Wifi", kw: "wireless network internet ssid" },
        { id: "bluetooth", name: "Bluetooth", icon: "bluetooth", c: blue, group: 1, file: "Bluetooth", kw: "devices headphones pair" },
        { id: "network", name: "Network", icon: "network", c: blue, group: 1, file: "Network", kw: "ethernet firewall ip dns proxy" },
        { id: "battery", name: "Battery", icon: "battery.100", c: ["#6BDC72", "#2FBF4A"], group: 1, file: "Battery", kw: "power energy low power mode", when: "battery" },
        { id: "energy", name: "Energy", icon: "bolt.fill", c: ["#6BDC72", "#2FBF4A"], group: 1, file: "Battery", kw: "power sleep low power mode", when: "nobattery" },

        { id: "general", name: "General", icon: "gearshape", c: gray, group: 2, file: "General", kw: "about storage software update date time language region sharing" },
        { id: "accessibility", name: "Accessibility", icon: "accessibility", c: blue, group: 2, file: "Static", kw: "vision hearing motor zoom voiceover" },
        { id: "appearance", name: "Appearance", icon: "circle.lefthalf.filled", c: black, group: 2, file: "Appearance", kw: "dark mode light accent color theme liquid glass" },
        { id: "intelligence", name: "Apple Intelligence & Siri", icon: "apple.intelligence", c: ["#F7A35C", "#B46CF0"], multi: true, group: 2, file: "Static", kw: "siri assistant" },
        { id: "desktop-dock", name: "Desktop & Dock", icon: "menubar.dock.rectangle", c: black, group: 2, file: "DesktopDock", kw: "dock magnification hide size mission control hot corners windows stage manager" },
        { id: "displays", name: "Displays", icon: "sun.max.fill", c: blue, group: 2, file: "Displays", kw: "resolution scale night shift brightness monitor" },
        { id: "menubar", name: "Menu Bar", icon: "menubar.rectangle", c: gray, group: 2, file: "MenuBar", kw: "control center menu bar controls clock" },
        { id: "spotlight", name: "Spotlight", icon: "magnifyingglass", c: blue, group: 2, file: "Static", kw: "search" },
        { id: "wallpaper", name: "Wallpaper", icon: "settings.wallpaper", c: ["#6BD8F5", "#26B2E0"], group: 2, file: "Wallpaper", kw: "desktop picture background screen saver" },

        { id: "notifications", name: "Notifications", icon: "bell.badge.fill", c: ["#FF6F61", "#F2362C"], group: 3, file: "Notifications", kw: "alerts banners previews" },
        { id: "sound", name: "Sound", icon: "speaker.wave.3.fill", c: ["#FF5A73", "#F2284B"], group: 3, file: "Sound", kw: "volume output input alert microphone speakers" },
        { id: "focus", name: "Focus", icon: "moon.fill", c: ["#8A86FF", "#5B57E0"], group: 3, file: "Focus", kw: "do not disturb sleep work personal" },
        { id: "screentime", name: "Screen Time", icon: "hourglass", c: ["#8A6CFF", "#5E3FD8"], group: 3, file: "Static", kw: "usage limits downtime" },

        { id: "lockscreen", name: "Lock Screen", icon: "lock.fill", c: black, group: 4, file: "LockScreen", kw: "screen saver password login window display off" },
        { id: "privacy", name: "Privacy & Security", icon: "hand.raised.fill", c: blue, group: 4, file: "Static", kw: "location camera microphone filevault firewall" },
        { id: "password", name: "Login Password", icon: "lock.fill", c: gray, group: 4, file: "Static", kw: "password touch id" },
        { id: "users", name: "Users & Groups", icon: "person.2.fill", c: blue, group: 4, file: "Users", kw: "accounts guest login" },

        { id: "accounts", name: "Internet Accounts", icon: "at", c: blue, group: 5, file: "Static", kw: "mail contacts calendars" },
        { id: "gamecenter", name: "Game Center", icon: "gamecontroller", c: ["#FFFFFF", "#ECECEC"], glyph: "#7B61FF", group: 5, file: "Static", kw: "games friends" },
        { id: "icloud", name: "iCloud", icon: "icloud.fill", c: ["#5DB9FF", "#1C8BF0"], group: 5, file: "Static", kw: "drive photos" },
        { id: "wallet", name: "Wallet & Apple Pay", icon: "wallet.pass.fill", c: black, group: 5, file: "Static", kw: "cards pay" },

        { id: "keyboard", name: "Keyboard", icon: "keyboard.fill", c: gray, group: 6, file: "Keyboard", kw: "key repeat delay input sources layout shortcuts dictation" },
        { id: "mouse", name: "Mouse", icon: "computermouse", c: gray, group: 6, file: "Mouse", kw: "tracking speed natural scrolling pointer", when: "mouse" },
        { id: "trackpad", name: "Trackpad", icon: "trackpad", c: gray, group: 6, file: "Trackpad", kw: "tap to click natural scrolling tracking gestures", when: "touchpad" },
        { id: "printers", name: "Printers & Scanners", icon: "printer.fill", c: gray, group: 6, file: "Static", kw: "printer scanner cups" },

        // ---- Sous-panneaux de General ----
        { id: "about", name: "About", icon: "laptopcomputer", c: gray, parent: "general", file: "About", kw: "mac name chip memory serial version nixos" },
        { id: "softwareupdate", name: "Software Update", icon: "gearshape", c: gray, parent: "general", file: "SoftwareUpdate", kw: "upgrade nixos rebuild" },
        { id: "storage", name: "Storage", icon: "internaldrive", c: gray, parent: "general", file: "Storage", kw: "disk space" },
        { id: "applecare", name: "AppleCare & Warranty", icon: "apple.logo", c: ["#FF5A5F", "#E0353B"], parent: "general", file: "Generic", kw: "coverage" },
        { id: "airdrop", name: "AirDrop & Continuity", icon: "airdrop", c: blue, parent: "general", file: "Generic", kw: "handoff airplay" },
        { id: "autofill", name: "AutoFill & Passwords", icon: "key.fill", c: gray, parent: "general", file: "Generic", kw: "passwords passkeys" },
        { id: "datetime", name: "Date & Time", icon: "calendar.clock", c: blue, parent: "general", file: "DateTime", kw: "clock time zone 24-hour ntp" },
        { id: "language", name: "Language & Region", icon: "globe", c: blue, parent: "general", file: "Language", kw: "locale region calendar temperature format" },
        { id: "loginitems", name: "Login Items & Extensions", icon: "list.bullet.rectangle", c: gray, parent: "general", file: "LoginItems", kw: "startup autostart" },
        { id: "sharing", name: "Sharing", icon: "person.wave.2", c: gray, parent: "general", file: "Sharing", kw: "file sharing remote login screen sharing hostname" },
        { id: "startupdisk", name: "Startup Disk", icon: "internaldrive", c: gray, parent: "general", file: "Generic", kw: "boot" },
        { id: "timemachine", name: "Time Machine", icon: "clock.arrow.circlepath", c: ["#4FC0B8", "#1F9A92"], parent: "general", file: "Generic", kw: "backup" },
        { id: "devicemanagement", name: "Device Management", icon: "checkmark.shield", c: gray, parent: "general", file: "Generic", kw: "mdm profiles" },
        { id: "transfer", name: "Transfer or Reset", icon: "arrow.counterclockwise", c: gray, parent: "general", file: "Generic", kw: "erase reset migration" },

        // ---- Carte utilisateur ----
        { id: "account", name: "", icon: "", c: gray, file: "Account", kw: "account user name" }
    ]

    function info(id) { return catalog.find(p => p.id === id) ?? null; }
    function available(p) {
        if (!p) return false;
        if (p.when === "battery") return hasBattery;
        if (p.when === "nobattery") return !hasBattery;
        if (p.when === "touchpad") return hasTouchpad;
        if (p.when === "mouse") return hasMouse;
        return true;
    }
    // Panneaux de la barre latérale, par groupe
    readonly property var sidebarPanes: catalog.filter(p => p.group && available(p))
    // Titre de la barre de titre (la carte utilisateur affiche le nom)
    property string accountName: ""
    function title(id) {
        const p = info(id);
        if (!p) return "";
        return id === "account" ? accountName : p.name;
    }
    // Panneau de la barre latérale qui reste sélectionné (parent des sous-panneaux)
    readonly property string sidebarPane: info(pane)?.parent ?? pane

    // Recherche : panneaux (et sous-panneaux) dont le nom ou un mot-clé correspond
    readonly property var results: {
        const q = search.trim().toLowerCase();
        if (!q) return [];
        return catalog.filter(p => p.name && available(p) &&
                              (p.name.toLowerCase().indexOf(q) >= 0 || (p.kw ?? "").indexOf(q) >= 0));
    }

    // ---- Identifiants acceptés par open() ----
    // Noms des panneaux de gnome-control-center (appelés par le Control Center
    // et l'ancien lanceur) et ancres façon macOS (x-apple.systempreferences:…).
    readonly property var aliases: ({
        "wifi": "wifi", "wi-fi": "wifi", "wlan": "wifi", "wireless": "wifi",
        "bluetooth": "bluetooth", "network": "network", "wired": "network", "vpn": "network",
        "power": "battery", "battery": "battery", "energy": "battery",
        "general": "general", "system": "about", "info-overview": "about", "info": "about", "about": "about",
        "accessibility": "accessibility", "universal-access": "accessibility", "a11y": "accessibility",
        "appearance": "appearance", "ubuntu": "appearance", "color": "appearance",
        "background": "wallpaper", "wallpaper": "wallpaper",
        "display": "displays", "displays": "displays", "nightshift": "displays",
        "dock": "desktop-dock", "desktop": "desktop-dock", "desktop-dock": "desktop-dock", "multitasking": "desktop-dock",
        "menubar": "menubar", "control-center": "menubar", "controlcenter": "menubar",
        "search": "spotlight", "spotlight": "spotlight",
        "notifications": "notifications", "sound": "sound", "audio": "sound", "focus": "focus",
        "screentime": "screentime", "lock": "lockscreen", "lockscreen": "lockscreen", "lock-screen": "lockscreen",
        "privacy": "privacy", "security": "privacy", "password": "password",
        "users": "users", "user-accounts": "users", "online-accounts": "accounts", "accounts": "accounts",
        "keyboard": "keyboard", "region": "language", "language": "language",
        "mouse": "mouse", "trackpad": "trackpad", "touchpad": "trackpad",
        "printers": "printers", "datetime": "datetime", "date-time": "datetime",
        "storage": "storage", "sharing": "sharing", "software-update": "softwareupdate", "softwareupdate": "softwareupdate",
        "applications": "loginitems", "default-apps": "desktop-dock", "removable-media": "general"
    })
    function normalize(arg) {
        let a = String(arg ?? "").trim().toLowerCase();
        a = a.replace(/^x-apple\.systempreferences:/, "").replace(/^com\.apple\.(preference\.|settings\.)?/, "")
             .replace(/[-.]settings[-.]extension$/, "").replace(/-extension$/, "");
        if (!a) return "";
        if (info(a)) return a;
        return aliases[a] ?? "";
    }

    // ---- Navigation ----
    function go(id, noHistory) {
        if (!info(id) || id === pane) return;
        if (!noHistory) { backStack = backStack.concat([pane]); fwdStack = []; }
        pane = id;
    }
    function back() {
        if (!backStack.length) return;
        fwdStack = fwdStack.concat([pane]);
        pane = backStack[backStack.length - 1];
        backStack = backStack.slice(0, -1);
    }
    function forward() {
        if (!fwdStack.length) return;
        backStack = backStack.concat([pane]);
        pane = fwdStack[fwdStack.length - 1];
        fwdStack = fwdStack.slice(0, -1);
    }
    function open(arg) {
        const id = normalize(arg);
        if (id) go(id);
        if (shown) raiseRequested();
        shown = true;
    }
    function close() {
        shown = false;
        search = "";
    }
    function toggle() { if (shown) close(); else open(""); }
}
