pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Ordre d'empilement réel des fenêtres Hyprland.
//
// L'ordre de `hyprctl clients` est l'ordre de rendu (du fond vers le dessus),
// mais Quickshell ne l'expose pas : Hyprland.toplevels garde l'ordre de
// création et focusHistoryID ne reflète pas l'empilement (une fenêtre flottante
// focalisée n'est pas forcément au-dessus). On relit donc `hyprctl -j clients`
// à l'ouverture de Mission Control.
Singleton {
    id: root

    // adresse (sans 0x) -> rang d'empilement (0 = tout au fond)
    property var rank: ({})

    // Rang d'une fenêtre ; repli sur l'historique de focus si inconnue
    function rankOf(t) {
        const r = rank[t?.address ?? ""];
        if (r !== undefined) return r;
        return 10000 - (t?.lastIpcObject?.focusHistoryID ?? 0);
    }
    // Trie des HyprlandToplevel du fond vers le dessus
    function sort(list) {
        return list.slice().sort((a, b) => rankOf(a) - rankOf(b));
    }

    function refresh() {
        if (!proc.running) proc.running = true;
    }

    // (Le socket de requêtes d'Hyprland conviendrait aussi, mais Quickshell
    // journalise un avertissement à chaque fermeture de connexion par Hyprland.)
    Process {
        id: proc
        // (sans hyprctl : liste vide, repli sur l'historique de focus)
        command: ["sh", "-c", "hyprctl -j clients 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    const r = {};
                    list.forEach((c, i) => r[String(c.address).replace(/^0x/, "")] = i);
                    root.rank = r;
                } catch (e) {
                    // sortie illisible : on garde l'ordre précédent
                }
            }
        }
    }
}
