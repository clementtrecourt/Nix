pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Réglages de System Settings (settings/Prefs.qml, fichier d'état
// « system-settings.json ») vus par les composants du shell, en LECTURE SEULE.
// Le fichier est suivi en direct (inotify) : tout changement fait dans
// Réglages, ou à la main dans le JSON, s'applique sans redémarrer le shell.
// Clé absente (ou fichier absent) : valeur par défaut d'un Mac neuf sous
// macOS Tahoe 26.
//
// Pas d'import de qs.settings ici : la barre des menus, les notifications et
// l'écran de verrouillage n'ont ainsi aucune dépendance vers l'app Réglages.
Singleton {
    id: root

    // Défauts de Tahoe (mêmes valeurs que settings/Prefs.qml)
    readonly property var defaults: ({
        // Menu Bar : « Automatically hide and show the menu bar » =
        // always | desktop | fullscreen | never (Tahoe : In Full Screen Only)
        menuBarAutohide: "fullscreen",
        menuBarBackground: false,
        recentItems: 10,
        // show = Always Show in Menu Bar, active = Show When Active, hide
        menuControls: ({ wifi: "show", bluetooth: "active", focus: "active", sound: "active", display: "active",
                         nowPlaying: "active", battery: "show", spotlight: "show", siri: "hide", userSwitch: "hide",
                         screenMirroring: "active" }),
        userSwitchStyle: "icon",
        // Notifications : aperçus always | unlocked | never
        notifPreviews: "unlocked",
        notifSleeping: false,
        notifLocked: true,
        notifMirroring: false,
        appNotif: ({}),
        // Date & Time / Lock Screen
        clock24: false,
        clock24Lock: false,
        largeClock: "both",
        lockMessage: false,
        lockMessageText: ""
    })

    // Contenu brut du fichier ({} tant qu'il n'est pas lu)
    property var raw: ({})
    function get(k) { return raw[k] !== undefined && raw[k] !== null ? raw[k] : defaults[k]; }

    // ---- Barre des menus ----
    readonly property string menuBarAutohide: get("menuBarAutohide")
    readonly property bool menuBarBackground: !!get("menuBarBackground")
    readonly property int recentItems: Math.max(0, Number(get("recentItems")) || 0)
    readonly property var menuControls: Object.assign({}, defaults.menuControls, raw.menuControls ?? {})
    // État d'un contrôle de la barre : "show" | "active" | "hide"
    function control(id) { return menuControls[id] ?? "hide"; }
    readonly property string userSwitchStyle: get("userSwitchStyle")

    // ---- Horloge ----
    readonly property bool clock24: !!get("clock24")
    // Tahoe : « Show 24-hour time on Lock Screen » n'a d'effet qu'avec « 24-hour time »
    readonly property bool lockClock24: clock24 && !!get("clock24Lock")

    // ---- Écran de verrouillage ----
    readonly property string largeClock: get("largeClock")
    readonly property bool lockMessage: !!get("lockMessage")
    readonly property string lockMessageText: String(get("lockMessageText") ?? "")

    // ---- Notifications ----
    readonly property string notifPreviews: get("notifPreviews")
    readonly property bool notifSleeping: !!get("notifSleeping")
    readonly property bool notifLocked: !!get("notifLocked")
    readonly property bool notifMirroring: !!get("notifMirroring")
    readonly property var appNotif: get("appNotif") ?? ({})
    readonly property var appNotifDefaults: ({ allow: true, style: "temporary", badge: true, sound: true, previews: "default",
                                               grouping: "auto", desktop: true, center: true, lock: true })
    // Réglages d'une app (clé = id de l'entrée .desktop, comparée sans casse ;
    // `alt` : autre nom possible de l'app, ex. le nom D-Bus)
    function appConf(key, alt) {
        const want = [String(key ?? "").toLowerCase(), String(alt ?? "").toLowerCase()].filter(s => s);
        let c = null;
        for (const id of Object.keys(appNotif)) {
            const l = id.toLowerCase();
            if (want.some(w => w === l || w === l.replace(/\.desktop$/, "") || w === l.split(".").pop())) { c = appNotif[id]; break; }
        }
        return Object.assign({}, appNotifDefaults, c ?? {});
    }

    FileView {
        id: file
        path: Quickshell.statePath("system-settings.json")
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                root.raw = (o && typeof o === "object") ? o : ({});
            } catch (e) {
                // Écriture en cours (fichier tronqué) : on garde l'état courant
            }
        }
        onLoadFailed: root.raw = ({})
    }
}
