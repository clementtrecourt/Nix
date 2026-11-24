pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Bureaux ("Spaces") façon macOS au-dessus des workspaces Hyprland numérotés.
//
// Hyprland détruit un workspace vide dès qu'on le quitte : pour qu'un bureau
// créé avec "+" survive, on mémorise le nombre de bureaux (`count`) dans
// ~/.local/state/quickshell/.../spaces.json. La liste affichée est donc
// 1..count, complétée par tout workspace numéroté existant au-delà.
Singleton {
    id: root

    // Nombre de bureaux voulus par l'utilisateur (au moins 1)
    property int count: 1

    // Workspace actif de l'écran focalisé
    readonly property int current: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    // Identifiants des bureaux, triés
    readonly property var ids: {
        let max = Math.max(1, count);
        for (const w of Hyprland.workspaces.values)
            if (w.id > max) max = w.id;
        const out = [];
        for (let i = 1; i <= max; i++) out.push(i);
        return out;
    }

    // Libellé : "Desktop N", ou le nom de l'app pour un bureau occupé par une
    // fenêtre plein écran (comme les Spaces plein écran de macOS)
    function label(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (ws?.hasFullscreen) {
            const t = Hyprland.toplevels.values.find(t => t.workspace?.id === id && (t.lastIpcObject?.fullscreen ?? 0) > 0);
            if (t) return Apps.displayName(Windows.classOf(t));
        }
        return "Desktop " + id;
    }

    // Fenêtres (HyprlandToplevel) d'un bureau, hors fenêtres minimisées
    function windowsOn(id) {
        return Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === id);
    }

    function goTo(id) { Hyprland.dispatch("workspace " + id); }

    // "+" : nouveau bureau vide à la fin (comme macOS, on ne s'y rend pas)
    function add() {
        count = ids.length + 1;
        save();
        return count;
    }

    // Envoie une fenêtre sur un bureau sans la suivre
    function moveWindow(t, id) {
        if (!t) return;
        Hyprland.dispatch("movetoworkspacesilent " + id + ",address:0x" + t.address);
    }

    // Ferme un bureau : ses fenêtres rejoignent le bureau précédent (ou le
    // suivant pour le bureau 1), puis les bureaux suivants sont renumérotés
    // pour ne pas laisser de trou (Bureau 4 devient Bureau 3...).
    function remove(id) {
        const all = ids;
        if (all.length <= 1) return;
        // Bureau 1 : ses fenêtres restent sur 1, où le bureau 2 vient se fondre
        if (id > 1)
            for (const t of windowsOn(id)) moveWindow(t, id - 1);
        for (let j = id + 1; j <= all[all.length - 1]; j++)
            for (const t of windowsOn(j)) moveWindow(t, j - 1);
        if (current >= id && current > 1) goTo(current - 1);
        count = Math.max(1, all.length - 1);
        save();
    }

    function save() {
        store.adapter.count = count;
        store.writeAdapter();
    }

    FileView {
        id: store
        path: Quickshell.statePath("spaces.json")
        printErrors: false
        watchChanges: false
        onLoaded: root.count = Math.max(1, adapter.count)
        adapter: JsonAdapter {
            property int count: 1
        }
    }
}
