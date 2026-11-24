pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// État des écrans utile aux réglages de System Settings, en lecture seule :
//  - asleep : tous les écrans actifs sont en veille (DPMS) ;
//  - mirroring : un écran en recopie d'un autre ;
//  - sharing : partage d'écran en cours (screencast).
// Hyprland ne signale ni la veille DPMS ni la recopie (et Quickshell ne liste
// pas les écrans en recopie) : `hyprctl monitors all -j` est relu
// périodiquement, seulement quand un réglage en dépend.
Singleton {
    id: root

    property bool asleep: false
    property bool mirroring: false
    property bool sharing: false

    // Lecture périodique demandée (notifications retenues en veille / recopie,
    // contrôle Screen Mirroring « Show When Active »)
    readonly property bool wanted: !SystemPrefs.notifSleeping || !SystemPrefs.notifMirroring
                                   || SystemPrefs.control("screenMirroring") === "active"

    function refresh() { if (!probe.running) probe.running = true; }

    Process {
        id: probe
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(text).filter(m => !m.disabled);
                    root.asleep = mons.length > 0 && mons.every(m => m.dpmsStatus === false);
                    root.mirroring = mons.some(m => m.mirrorOf !== undefined && m.mirrorOf !== "none");
                } catch (e) {
                    // Hyprland indisponible : état inchangé
                }
            }
        }
    }
    Timer {
        interval: 4000
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // « screencast>>1,0 » : début (1) / fin (0) d'un partage d'écran
            if (event.name === "screencast") root.sharing = event.data.split(",")[0] === "1";
            else if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2"].includes(event.name)) root.refresh();
        }
    }
}
