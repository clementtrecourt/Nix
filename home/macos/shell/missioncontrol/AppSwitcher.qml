import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Sélecteur d'applications Cmd+Tab (macOS Tahoe).
//
//  - Cmd+Tab / Cmd+Maj+Tab (raccourcis globaux "switcher-next" / "switcher-prev")
//    démarrent une séquence ; le panneau n'apparaît que si Cmd reste enfoncé
//    plus de 120 ms : un Cmd+Tab rapide bascule directement vers l'app précédente.
//  - Relâcher Cmd ("switcher-commit", bindrt côté Hyprland) active l'app choisie :
//    sa dernière fenêtre utilisée est focalisée, ses autres fenêtres remontent.
//  - Ordre MRU maintenu ici à partir de Hyprland.activeToplevel.
Scope {
    id: root

    // ---- Ordre MRU (classes, la plus récente d'abord) ----
    property var mru: []
    // Dernière fenêtre utilisée par app (classe en minuscules -> HyprlandToplevel)
    property var lastWin: ({})

    function noteActive() {
        const t = Hyprland.activeToplevel;
        const c = Windows.classOf(t);
        if (!t || !c) return;
        const key = c.toLowerCase();
        lastWin[key] = t;
        if (mru.length && mru[0].toLowerCase() === key) return;
        mru = [c].concat(mru.filter(x => x.toLowerCase() !== key));
    }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root.noteActive(); }
    }
    Connections {
        target: Windows
        // La classe arrive parfois après le changement de fenêtre active
        function onActiveClassChanged() { root.noteActive(); }
    }

    // Démarrage : ordre initial d'après l'historique de focus d'Hyprland
    Component.onCompleted: { Hyprland.refreshToplevels(); seedTimer.start(); }
    Timer {
        id: seedTimer
        interval: 600
        onTriggered: {
            const ts = Windows.toplevels.slice().sort((a, b) =>
                (a.lastIpcObject?.focusHistoryID ?? 1e9) - (b.lastIpcObject?.focusHistoryID ?? 1e9));
            const seen = root.mru.map(c => c.toLowerCase());
            const add = [];
            for (const t of ts) {
                const c = Windows.classOf(t);
                if (!c || seen.includes(c.toLowerCase())) continue;
                seen.push(c.toLowerCase());
                add.push(c);
                if (!root.lastWin[c.toLowerCase()]) root.lastWin[c.toLowerCase()] = t;
            }
            root.mru = root.mru.concat(add);
        }
    }

    // Apps ouvertes, ordre MRU (les apps jamais focalisées à la fin)
    readonly property var apps: {
        const running = Windows.runningClasses;
        const low = running.map(c => c.toLowerCase());
        const out = mru.filter(c => low.includes(c.toLowerCase()));
        const outLow = out.map(c => c.toLowerCase());
        for (const c of running) if (!outLow.includes(c.toLowerCase())) out.push(c);
        return out;
    }

    // ---- Séquence Cmd+Tab ----
    property bool active: false      // Cmd+Tab en cours (Cmd encore enfoncé)
    property bool shown: false       // panneau visible
    property var items: []           // apps figées au début de la séquence
    property int index: 0

    function step(dir) {
        if (!active) {
            const list = apps;
            if (list.length === 0) return;
            items = list;
            active = true;
            // L'app 0 est au premier plan sauf si aucune fenêtre n'est active (bureau).
            // (Au lancement du shell, activeToplevel n'est connu qu'au premier
            // changement de focus : l'historique d'Hyprland sert alors de repli.)
            const hasFront = Hyprland.activeToplevel
                ? !!Windows.activeClass
                : Windows.toplevels.some(t => t.lastIpcObject?.focusHistoryID === 0 && !Windows.isMinimized(t));
            const front = hasFront ? 1 : 0;
            index = dir > 0 ? Math.min(front, list.length - 1) : list.length - 1;
            showTimer.restart();
            return;
        }
        if (items.length) index = (index + dir + items.length) % items.length;
    }
    function select(i) { if (active && i >= 0 && i < items.length) index = i; }

    function commit() {
        if (!active) return;
        const cls = items[index];
        reset();
        if (!cls) return;
        // La surface du sélecteur rend le clavier avant que l'on focalise une fenêtre
        activateLater.cls = cls;
        activateLater.restart();
    }
    function cancel() { reset(); }
    function reset() {
        showTimer.stop();
        active = false;
        shown = false;
        if (ShellState.openPanel === "appswitcher") ShellState.close();
    }

    // Q pendant le sélecteur : quitter l'app sélectionnée (elle sort de la liste)
    function quitSelected() {
        const cls = items[index];
        if (!cls) return;
        Windows.quitApp(cls);
        items = items.filter((c, i) => i !== index);
        if (items.length === 0) { reset(); return; }
        index = Math.min(index, items.length - 1);
    }
    // H : masquer l'app sélectionnée (fenêtres minimisées)
    function hideSelected() {
        const cls = items[index];
        if (!cls) return;
        for (const t of Windows.windowsOf(cls)) if (!Windows.isMinimized(t)) Windows.minimize(t);
    }

    // Active une app : dernière fenêtre utilisée au premier plan, ses autres
    // fenêtres du même bureau remontées juste en dessous (comportement macOS).
    function activate(cls) {
        const ws = Windows.windowsOf(cls);
        if (ws.length === 0) return;
        const visible = ws.filter(t => !Windows.isMinimized(t));
        let target = lastWin[cls.toLowerCase()];
        if (!target || !ws.includes(target) || (Windows.isMinimized(target) && visible.length))
            target = visible.slice().sort((a, b) =>
                (a.lastIpcObject?.focusHistoryID ?? 1e9) - (b.lastIpcObject?.focusHistoryID ?? 1e9))[0] ?? ws[0];
        const others = visible
            .filter(t => t !== target && t.workspace?.id === target.workspace?.id)
            .sort((a, b) => (b.lastIpcObject?.focusHistoryID ?? 0) - (a.lastIpcObject?.focusHistoryID ?? 0));
        for (const t of others) Hyprland.dispatch("alterzorder top,address:0x" + t.address);
        // La fenêtre choisie tout au-dessus (focuswindow ne remonte pas
        // forcément une fenêtre flottante)
        if (!Windows.isMinimized(target)) Hyprland.dispatch("alterzorder top,address:0x" + target.address);
        Windows.focus(target);
        // Hyprland peut redonner le focus à l'ancienne fenêtre en démappant la
        // surface du sélecteur après notre focuswindow : on vérifie et on insiste.
        verifyFocus.target = target;
        verifyFocus.restart();
    }
    Timer {
        id: verifyFocus
        property var target: null
        interval: 160
        onTriggered: {
            if (target && Hyprland.activeToplevel !== target && !Windows.isMinimized(target))
                Hyprland.dispatch("focuswindow address:0x" + target.address);
            target = null;
        }
    }

    Timer {
        id: showTimer
        interval: 120
        onTriggered: {
            root.shown = true;
            ShellState.open("appswitcher");
        }
    }
    Timer {
        id: activateLater
        property string cls: ""
        interval: 40
        onTriggered: root.activate(cls)
    }
    // Un autre panneau s'ouvre (Spotlight...) : on abandonne
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (root.shown && ShellState.openPanel !== "appswitcher") root.reset();
        }
    }

    // ---- Raccourcis globaux (liés par Hyprland : global, macos:<nom>) ----
    // `pressed` seulement : le dispatcher "global" d'Hyprland envoie aussi le
    // relâchement de la touche.
    GlobalShortcut {
        appid: "macos"
        name: "switcher-next"
        description: "Application suivante (Cmd+Tab)"
        onPressed: root.step(1)
    }
    GlobalShortcut {
        appid: "macos"
        name: "switcher-prev"
        description: "Application précédente (Cmd+Maj+Tab)"
        onPressed: root.step(-1)
    }
    // Relâchement de Cmd (bindrt) : selon la version d'Hyprland l'événement
    // arrive en "released" ou en "pressed" ; commit() est idempotent.
    GlobalShortcut {
        appid: "macos"
        name: "switcher-commit"
        description: "Valider le sélecteur (relâchement de Cmd)"
        onPressed: root.commit()
        onReleased: root.commit()
    }

    // ---- Panneau (écran focalisé) ----
    Variants {
        model: Quickshell.screens

        SwitcherPanel {
            required property var modelData
            screen: modelData
            switcher: root
            // Surface présente pendant toute la séquence (clavier), contenu visible après 120 ms
            visible: root.active && (Hyprland.focusedMonitor?.name ?? "") === modelData.name
        }
    }

    // Débogage (banc de test) : quickshell ipc call switcher-debug next
    IpcHandler {
        target: "switcher-debug"
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function commit(): void { root.commit(); }
        function cancel(): void { root.cancel(); }
        function state(): string {
            return JSON.stringify({ active: root.active, shown: root.shown, index: root.index, items: root.items, mru: root.mru, apps: root.apps });
        }
    }
}
