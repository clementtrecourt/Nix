pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Widgets du Centre de notifications (liste ordonnée, doublons permis comme sur
// macOS) et catalogue de la galerie de widgets (« Edit Widgets »).
// Persistance : widgets.json (Quickshell.statePath) = { "list": ["upnext", …] }.
Singleton {
    id: root

    // Catalogue : un widget par taille et par app, comme la galerie de macOS.
    // `appId` : entrée .desktop ouverte au clic (et icône de la barre latérale).
    readonly property var catalog: [
        { id: "upnext", app: "Calendar", appId: "org.gnome.calendar", name: "Up Next",
          desc: "See your upcoming events.", w: 344, h: 164 },
        { id: "calendar", app: "Calendar", appId: "org.gnome.calendar", name: "Month",
          desc: "View the current month at a glance.", w: 164, h: 164 },
        { id: "clock", app: "Clock", appId: "org.gnome.clocks", name: "City",
          desc: "See the time in a city.", w: 164, h: 164 }
    ]
    // Apps qui ont des widgets (catégories de la barre latérale), ordre alphabétique
    readonly property var apps: {
        const l = [];
        for (const c of catalog) if (!l.some(a => a.app === c.app)) l.push({ app: c.app, appId: c.appId });
        return l.sort((a, b) => a.app.localeCompare(b.app));
    }
    function info(id) { return catalog.find(c => c.id === id) ?? null; }

    readonly property var defaults: ["upnext", "calendar", "clock"]
    property var widgets: defaults

    // Galerie ouverte (mode édition du Centre de notifications)
    property bool editing: false
    // Fenêtre de la galerie (pour le HyprlandFocusGrab du Centre)
    property QtObject galleryWindow: null

    function add(id) {
        if (!info(id)) return;
        widgets = widgets.concat([id]);
        save();
    }
    function removeAt(i) {
        if (i < 0 || i >= widgets.length) return;
        const l = widgets.slice();
        l.splice(i, 1);
        widgets = l;
        save();
    }
    // Ouvre l'app du widget (clic sur un widget du Centre)
    function openApp(id) {
        const c = info(id);
        if (c) Apps.launch(c.appId);
    }

    function save() { file.setText(JSON.stringify({ list: widgets })); }
    FileView {
        id: file
        path: Quickshell.statePath("widgets.json")
        printErrors: false
        blockLoading: true
        atomicWrites: true
    }
    Component.onCompleted: {
        try {
            const j = JSON.parse(file.text() || "{}");
            if (Array.isArray(j.list)) widgets = j.list.filter(w => info(w));
            // Ancien format : { hidden: [...] } (widgets masqués parmi les trois)
            else if (Array.isArray(j.hidden)) widgets = defaults.filter(w => !j.hidden.includes(w));
        } catch (e) {}
    }
}
