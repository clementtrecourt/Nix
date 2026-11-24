pragma Singleton

import QtQuick
import Quickshell

// Applications : correspondance classe de fenêtre <-> entrée .desktop, icônes,
// lancement, liste des apps épinglées au Dock.
Singleton {
    id: root

    // Apps du Dock (ids .desktop sans l'extension). Surchargé par Nix via
    // ~/.config/quickshell/macos/settings.json si présent (clé "dock.pinned").
    property list<string> pinned: [
        "nemo",            // Finder
        "zen-beta",
        "kitty",
        "dev.zed.Zed",
        "spotify",
        "org.gnome.Settings"
    ]

    readonly property var all: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // Entrée .desktop pour un id ou une classe de fenêtre (insensible à la casse,
    // tolère "org.foo.Bar" vs "bar", StartupWMClass).
    function entryFor(idOrClass) {
        if (!idOrClass) return null;
        const exact = DesktopEntries.byId(idOrClass);
        if (exact) return exact;
        const heur = DesktopEntries.heuristicLookup(idOrClass);
        return heur ?? null;
    }

    function name(idOrClass) {
        const e = entryFor(idOrClass);
        return e ? e.name : (idOrClass ?? "");
    }

    // Chemin d'icône (thème d'icônes courant, MacTahoe en prod).
    function icon(idOrClass) {
        const e = entryFor(idOrClass);
        const n = e && e.icon ? e.icon : idOrClass;
        return Quickshell.iconPath(n, "application-x-executable");
    }

    function launch(idOrClass) {
        const e = entryFor(idOrClass);
        if (e) e.execute();
        else Quickshell.execDetached([idOrClass]);
    }

    // ---- Noms macOS (ajout agent dock) ----
    // Les apps dont le thème MacTahoe-Apple affiche l'icône d'une app Apple
    // (pkgs/mactahoe-apple-icon-theme.nix) portent aussi son nom anglais US :
    // l'icône et le nom restent cohérents (bulle du Dock, menus, Spotlight…).
    // Clés en minuscules (id .desktop sans extension ou classe de fenêtre).
    readonly property var macNames: {
        const m = {};
        const groups = {
            "Finder": ["org.quickshell", "nemo", "nautilus", "org.gnome.nautilus", "thunar", "org.kde.dolphin", "pcmanfm", "pcmanfm-qt", "caja", "system-file-manager"],
            "System Settings": ["org.gnome.settings", "gnome-control-center", "systemsettings", "org.kde.systemsettings", "preferences-system"],
            "Terminal": ["kitty", "foot", "footclient", "alacritty", "org.gnome.console", "org.gnome.terminal", "com.mitchellh.ghostty", "org.wezfurlong.wezterm"],
            "Activity Monitor": ["btop", "htop", "org.gnome.systemmonitor", "gnome-system-monitor", "io.missioncenter.missioncenter"],
            "Preview": ["imv", "org.gnome.loupe", "eog", "org.gnome.eog", "org.pwmt.zathura", "org.gnome.evince", "evince", "org.gnome.papers"],
            "QuickTime Player": ["mpv", "io.mpv.mpv", "vlc", "org.gnome.totem", "org.gnome.showtime"],
            "Calculator": ["org.gnome.calculator", "gnome-calculator", "org.kde.kcalc"],
            "Calendar": ["org.gnome.calendar"],
            "Clock": ["org.gnome.clocks"],
            "Contacts": ["org.gnome.contacts"],
            "Weather": ["org.gnome.weather"],
            "Maps": ["org.gnome.maps"],
            "TextEdit": ["org.gnome.texteditor", "gedit", "org.gnome.gedit"],
            "Disk Utility": ["org.gnome.diskutility", "gnome-disks"],
            "Font Book": ["org.gnome.font-viewer"],
            "Archive Utility": ["org.gnome.fileroller", "file-roller", "org.kde.ark"],
            "Keychain Access": ["org.gnome.seahorse.application", "seahorse"],
            "Passwords": ["org.gnome.world.secrets", "org.keepassxc.keepassxc", "keepassxc"],
            "Console": ["org.gnome.logs"],
            "Music": ["org.gnome.music"],
            "Photos": ["org.gnome.shotwell", "shotwell", "org.gnome.photos"],
            "Photo Booth": ["org.gnome.snapshot", "cheese"],
            "Books": ["com.github.johnfactotum.foliate"],
            "Time Machine": ["org.gnome.dejadup", "deja-dup"],
            "App Store": ["org.gnome.software"],
            "Reminders": ["org.gnome.todo", "io.github.alainm23.planify"],
            "Notes": ["org.gnome.notes"]
        };
        for (const n in groups) for (const k of groups[n]) m[k] = n;
        return m;
    }
    // Nom affiché d'une app : nom macOS ci-dessus, sinon Name= du .desktop
    // (localisé selon la langue du système), sinon id rendu lisible
    // (« org.gnome.Foo-bar » -> « Foo bar »).
    function displayName(idOrClass) {
        const raw = String(idOrClass ?? "").replace(/\.desktop$/i, "");
        if (!raw) return "";
        const k = raw.toLowerCase();
        if (macNames[k] !== undefined) return macNames[k];
        const e = entryFor(raw);
        if (e) {
            const ek = (e.id ?? "").toLowerCase();
            if (macNames[ek] !== undefined) return macNames[ek];
            if (e.name) return e.name;
        }
        const last = raw.split(".").pop() ?? raw;
        return last.replace(/[-_]+/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, c => c.toUpperCase());
    }
}
