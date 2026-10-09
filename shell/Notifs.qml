pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    property bool dnd: false
    readonly property var list: server.trackedNotifications

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => { n.tracked = true }
    }

    function dismissNewest() {
        const v = server.trackedNotifications.values
        if (v.length > 0) v[v.length - 1].dismiss()
    }

    function clear() {
        for (const n of [...server.trackedNotifications.values]) n.dismiss()
    }
}
