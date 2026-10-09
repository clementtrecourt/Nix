pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property color surface: a.surface
    readonly property color surfaceContainer: a.surfaceContainer
    readonly property color text: a.text
    readonly property color textMuted: a.textMuted
    readonly property color primary: a.primary
    readonly property color primaryText: a.primaryText
    readonly property color secondary: a.secondary
    readonly property color tertiary: a.tertiary
    readonly property color error: a.error
    readonly property color outline: a.outline

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/colors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: a
            property string surface: "#101418"
            property string surfaceContainer: "#1c2024"
            property string text: "#e0e2e8"
            property string textMuted: "#c2c7cf"
            property string primary: "#9ecaff"
            property string primaryText: "#003258"
            property string secondary: "#bbc7db"
            property string tertiary: "#d6bee4"
            property string error: "#ffb4ab"
            property string outline: "#8c9199"
        }
    }
}
