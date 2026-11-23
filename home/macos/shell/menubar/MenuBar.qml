import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Barre de menus macOS Tahoe : une barre par écran (Bar.qml), une couche de menu
// par écran (MenuLayer.qml), un état de menu partagé (MenuController.qml).
Scope {
    id: root

    MenuController {
        id: ctl
    }

    Menus {
        id: menuModel
        onAboutRequested: cls => about.show(cls)
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            Bar {
                screen: perScreen.modelData
                controller: ctl
                menus: menuModel
            }

            MenuLayer {
                screen: perScreen.modelData
                controller: ctl
                screenName: perScreen.modelData.name
            }
        }
    }

    // « À propos de <App> »
    AppAbout {
        id: about
    }

    // Pilotage de debug (banc de test sans souris) :
    //   quickshell ... ipc call menubar-debug open file
    //   quickshell ... ipc call menubar-debug key down|up|left|right|enter|escape|<lettre>
    function firstBar() {
        const b = ctl.bars;
        const k = Object.keys(b);
        return k.length ? b[k[0]] : null;
    }

    IpcHandler {
        target: "menubar-debug"

        function open(id: string): void {
            const b = root.firstBar();
            if (b) b.openMenu(id, null, false);
        }
        function openKeyboard(id: string): void {
            const b = root.firstBar();
            if (b) b.openMenu(id, null, true);
        }
        function close(): void { ctl.close(true); }
        function state(): string {
            return JSON.stringify({ open: ctl.openId, screen: ctl.screenName, closing: ctl.closing });
        }
        // Simule une touche dans le menu ouvert
        function key(name: string): void {
            const layerKeys = {
                down: p => p.move(1), up: p => p.move(-1), right: p => p.keyRight(),
                left: p => p.keyLeft(), enter: p => p.keyEnter(),
                escape: p => (p.parentPanel ? p.parentPanel.closeSub() : ctl.close(true))
            };
            const p = ctl.rootPanel;
            if (!p) return;
            if (layerKeys[name]) layerKeys[name](p.deepest());
        }
        // Survole l'élément <index> du menu le plus profond (ouvre son sous-menu)
        function hover(index: int): void {
            const p = ctl.rootPanel;
            if (p) p.deepest().hover(index);
        }
        // Force la couleur du texte : light | dark | auto
        function tone(mode: string): void {
            for (const b of Object.values(ctl.bars)) {
                b.forceLight = mode === "light";
                b.forceDark = mode === "dark";
            }
        }
        // État des barres (luminance du fond, plein écran…)
        function info(): string {
            return JSON.stringify(Object.values(ctl.bars).map(b => ({
                screen: b.screenName, luminance: b.backdropLuminance, light: b.light,
                fullscreen: b.fullscreen, revealed: b.revealed, tray: b.trayDebug()
            })));
        }
        // Ouvre le menu d'une icône d'état : battery | wifi
        function status(id: string): void {
            const b = root.firstBar();
            if (b) b.openStatusById(id);
        }
        // Plein écran : simule le pointeur contre le bord haut
        function reveal(on: bool): void {
            for (const b of Object.values(ctl.bars)) b.revealed = on;
        }
        function demo(on: bool): void {
            for (const b of Object.values(ctl.bars)) b.demo = on;
        }
        function percent(on: bool): void {
            for (const b of Object.values(ctl.bars)) b.showBatteryPercent = on;
        }
        function showAbout(cls: string): void { about.show(cls); }
        // Saisie dans le champ de recherche du menu Aide
        function search(text: string): void {
            const p = ctl.rootPanel;
            if (p) p.query = text;
        }
        // Ouvre le menu d'un élément de la barre d'état (index dans SystemTray)
        function tray(index: int): void {
            const b = root.firstBar();
            if (b) b.openTrayIndex(index);
        }
    }
}
