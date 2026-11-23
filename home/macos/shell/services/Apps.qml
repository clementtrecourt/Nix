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
}
