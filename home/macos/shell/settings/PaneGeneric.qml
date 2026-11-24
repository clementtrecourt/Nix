import QtQuick

// Panneau en lecture seule pour les réglages sans équivalent sur cette machine
// (Apple Account, AppleCare, Time Machine…) : en-tête Tahoe et lignes grisées.
PaneBase {
    id: root

    readonly property var texts: ({
        applecare: ["AppleCare & Warranty", "View coverage details for this Mac and connected devices.", ["Limited Warranty", "Coverage Details…"]],
        airdrop: ["AirDrop & Continuity", "Share content and work across your Apple devices.", ["AirDrop", "Handoff", "AirPlay Receiver"]],
        autofill: ["AutoFill & Passwords", "Use AutoFill to fill in passwords, passkeys and verification codes.", ["AutoFill Passwords and Passkeys", "Verification Codes"]],
        startupdisk: ["Startup Disk", "Select the system you want to use to start up your computer.", ["NixOS"]],
        timemachine: ["Time Machine", "Back up your Mac with Time Machine.", ["Add Backup Disk…"]],
        devicemanagement: ["Device Management", "No profiles are installed on this Mac.", []],
        transfer: ["Transfer or Reset", "Transfer or erase content and settings.", ["Erase All Content and Settings…"]]
    })
    readonly property var t: texts[paneId] ?? [spec?.name ?? "", "", []]

    SHeaderCard {
        pane: root.spec
        description: root.t[1]
    }
    SGroup {
        visible: root.t[2].length > 0
        Repeater {
            model: root.t[2]
            SRow { required property string modelData; title: modelData; dimmed: true }
        }
    }
}
