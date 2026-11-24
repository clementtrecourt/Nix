import QtQuick

// General (Tahoe 26) : carte d'en-tête puis liste de sous-panneaux à pastilles
// grises (About, Software Update / Storage / AppleCare & Warranty / AirDrop &
// Continuity / AutoFill & Passwords, Date & Time, Language & Region, Login
// Items & Extensions, Sharing, Startup Disk, Time Machine / Device Management
// / Transfer or Reset), lignes de navigation à chevron.
PaneBase {
    id: root

    component NavGroup: SGroup {
        id: g
        property var ids: []
        Repeater {
            model: g.ids
            SRow {
                required property string modelData
                readonly property var p: Nav.info(modelData)
                title: p?.name ?? ""
                pane: p
                minHeight: 42
                chevron: true
                onClicked: Nav.go(modelData)
            }
        }
    }

    SHeaderCard {
        pane: root.spec
        description: "Manage your overall setup and preferences for Mac, such as software updates, device language, AirDrop, and more."
    }
    NavGroup { ids: ["about", "softwareupdate", "storage", "applecare"] }
    NavGroup { ids: ["airdrop", "autofill", "datetime", "language", "loginitems", "sharing", "startupdisk", "timemachine"] }
    NavGroup { ids: ["devicemanagement", "transfer"] }
}
