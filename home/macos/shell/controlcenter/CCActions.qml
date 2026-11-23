pragma Singleton

import QtQuick
import Quickshell

// Actions système du Control Center (liens « Réglages … »).
//
// Il n'y a pas de « Réglages Système » unique sous Hyprland : on essaie
// gnome-control-center <panneau> s'il est installé, sinon l'outil dédié
// présent dans la configuration (nm-connection-editor, blueman-manager,
// pavucontrol, nwg-look…). Sans aucun outil, le clic ne fait rien.
Singleton {
    // Outils de repli par panneau, dans l'ordre de préférence
    readonly property var fallbacks: ({
        wifi: ["nm-connection-editor"],
        network: ["nm-connection-editor"],
        bluetooth: ["blueman-manager", "overskride"],
        sound: ["pavucontrol", "pwvucontrol"],
        display: ["nwg-displays", "wdisplays"],
        notifications: ["nwg-look"],
        appearance: ["nwg-look"]
    })

    function openSettings(panel) {
        const alts = (fallbacks[panel] ?? []).map(c => 'command -v ' + c + ' >/dev/null && exec ' + c + ';').join(" ");
        Quickshell.execDetached(["sh", "-c",
            'if command -v gnome-control-center >/dev/null; then exec gnome-control-center "$1"; fi; ' + alts,
            "sh", panel]);
    }
}
