import QtQuick
import Quickshell
import qs.common

// Desktop & Dock (Tahoe 26, libellés d'Apple mchlp1119) : Dock (taille,
// agrandissement, position, effet de réduction, masquage automatique, apps
// suggérées et récentes) piloté via DockPrefs ; navigateur web par défaut
// (xdg-settings) ; les options sans équivalent sur ce bureau sont affichées
// grisées, comme Tahoe les montre.
PaneBase {
    id: root

    // Navigateurs installés (catégorie WebBrowser) et navigateur par défaut
    readonly property var browsers: DesktopEntries.applications.values.filter(e => (e.categories ?? []).includes("WebBrowser") && !e.noDisplay)
    property string defaultBrowser: ""
    ProcessText {
        id: browserProbe
        running: true
        command: ["sh", "-c", "xdg-settings get default-web-browser 2>/dev/null || xdg-mime query default x-scheme-handler/https"]
        onDone: (t) => root.defaultBrowser = t.trim().replace(/\.desktop$/, "")
    }
    ProcessText { id: browserSet; onExited: browserProbe.running = true }

    readonly property real sliderW: 210

    SSection { text: "Dock" }
    SGroup {
        SRow {
            title: "Size"
            minHeight: 50
            SSlider {
                width: root.sliderW
                minLabel: "Small"; maxLabel: "Large"
                value: (DockPrefs.tileSize - 16) / (128 - 16)
                onMoved: (v) => DockPrefs.setTileSize(Math.round(16 + v * 112))
            }
        }
        SRow {
            title: "Magnification"
            minHeight: 50
            Row {
                spacing: 12
                SSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -7
                    checked: DockPrefs.magnification
                    onToggled: (on) => DockPrefs.setMagnification(on)
                }
                SSlider {
                    width: root.sliderW - 48
                    enabledSlider: DockPrefs.magnification
                    minLabel: "Small"; maxLabel: "Large"
                    value: (DockPrefs.largeSize - 16) / (128 - 16)
                    onMoved: (v) => DockPrefs.setLargeSize(Math.max(DockPrefs.tileSize, Math.round(16 + v * 112)))
                }
            }
        }
        SRow {
            title: "Position on screen"
            SPopUp {
                options: [{ text: "Left", value: "left", enabled: false }, { text: "Bottom", value: "bottom" }, { text: "Right", value: "right", enabled: false }]
                value: "bottom"
            }
        }
        SRow {
            title: "Minimize windows using"
            SPopUp {
                options: [{ text: "Genie Effect", value: "genie" }, { text: "Scale Effect", value: "scale" }]
                value: DockPrefs.minimizeEffect
                onActivated: (v) => DockPrefs.setMinimizeEffect(v)
            }
        }
        SRow {
            title: "Double-click a window’s title bar to"
            dimmed: true
            SPopUp { options: [{ text: "Fill", value: "fill" }, { text: "Zoom", value: "zoom" }, { text: "Minimize", value: "minimize" }, { text: "Do Nothing", value: "none" }]; value: "zoom"; enabledPopUp: false }
        }
        SRow { title: "Minimize windows into application icon"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow {
            title: "Automatically hide and show the Dock"
            SSwitch { checked: DockPrefs.autohide; onToggled: (on) => DockPrefs.setAutohide(on) }
        }
        SRow { title: "Animate opening applications"; dimmed: true; SSwitch { checked: true; enabledSwitch: false } }
        SRow { title: "Show indicators for open applications"; dimmed: true; SSwitch { checked: true; enabledSwitch: false } }
        SRow {
            title: "Show suggested and recent apps in Dock"
            SSwitch { checked: DockPrefs.showRecents; onToggled: (on) => DockPrefs.setShowRecents(on) }
        }
    }

    SSection { text: "Desktop & Stage Manager" }
    SGroup {
        SRow {
            title: "Show Items"
            dimmed: true
            Row { spacing: 14; SCheckBox { text: "On Desktop"; checked: false; enabledBox: false } SCheckBox { text: "In Stage Manager"; checked: false; enabledBox: false } }
        }
        SRow {
            title: "Click wallpaper to reveal desktop"
            dimmed: true
            SPopUp { options: [{ text: "Always", value: "always" }, { text: "Only in Stage Manager", value: "stage" }]; value: "stage"; enabledPopUp: false }
        }
        SRow {
            title: "Stage Manager"
            subtitle: "Stage Manager arranges your recent windows into a single strip for reduced clutter and quick access."
            dimmed: true
            SSwitch { checked: false; enabledSwitch: false }
        }
    }

    SSection { text: "Widgets" }
    SGroup {
        SRow {
            title: "Show Widgets"
            dimmed: true
            Row { spacing: 14; SCheckBox { text: "On Desktop"; checked: false; enabledBox: false } SCheckBox { text: "In Stage Manager"; checked: false; enabledBox: false } }
        }
        SRow {
            title: "Widget style"
            dimmed: true
            SPopUp { options: [{ text: "Automatic", value: "auto" }, { text: "Monochrome", value: "mono" }, { text: "Full-color", value: "full" }]; value: "auto"; enabledPopUp: false }
        }
        SRow { title: "Use iPhone widgets"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
    }

    SGroup {
        SRow {
            title: "Default web browser"
            SPopUp {
                options: root.browsers.map(b => ({ text: b.name, value: b.id }))
                value: root.defaultBrowser
                onActivated: (v) => {
                    root.defaultBrowser = v;
                    browserSet.command = ["sh", "-c", 'xdg-settings set default-web-browser "$1.desktop" 2>/dev/null || { xdg-mime default "$1.desktop" x-scheme-handler/http x-scheme-handler/https text/html; }', "sh", v];
                    browserSet.running = true;
                }
            }
        }
    }

    SSection { text: "Windows" }
    SGroup {
        SRow {
            title: "Prefer tabs when opening documents"
            dimmed: true
            SPopUp { options: [{ text: "Never", value: "never" }, { text: "Always", value: "always" }, { text: "In Full Screen", value: "fullscreen" }]; value: "fullscreen"; enabledPopUp: false }
        }
        SRow { title: "Ask to keep changes when closing documents"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Close windows when quitting an application"; subtitle: "When enabled, open documents and windows will not be restored when you re-open an application."; dimmed: true; SSwitch { checked: true; enabledSwitch: false } }
        SRow { title: "Drag windows to screen edges to tile"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Drag windows to menu bar to fill screen"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Hold ⌥ key while dragging windows to tile"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Tiled windows have margins"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
    }

    SSection { text: "Mission Control" }
    SNote { text: "Mission Control shows an overview of your open windows and thumbnails of full-screen applications, all arranged in a unified view." }
    SGroup {
        SRow { title: "Automatically rearrange Spaces based on most recent use"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "When switching to an application, switch to a Space with open windows for the application"; dimmed: true; SSwitch { checked: true; enabledSwitch: false } }
        SRow { title: "Group windows by application"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Displays have separate Spaces"; dimmed: true; SSwitch { checked: true; enabledSwitch: false } }
        SRow { title: "Drag windows to top of screen to enter Mission Control"; dimmed: true; SSwitch { checked: true; enabledSwitch: false } }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Shortcuts…"; enabledButton: false }
            SButton { text: "Hot Corners…"; enabledButton: false }
            HelpButton { url: "https://support.apple.com/guide/mac-help/mchlp1119/mac" }
        }
    }
}
