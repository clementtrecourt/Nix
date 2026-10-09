import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
        NotificationPopups {}

    IpcHandler {
        target: "notifs"
        function dismiss(): void { Notifs.dismissNewest() }
        function clear(): void { Notifs.clear() }
        function toggleDnd(): void { Notifs.dnd = !Notifs.dnd }
    }

        LazyLoader {
        id: launcher
        AppLauncher { onDone: launcher.active = false }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.active = !launcher.active }
    }
    LazyLoader {
        id: picker
        WallpaperPicker { onDone: picker.active = false }
    }
        LazyLoader {
        id: clip
        ClipboardHistory { onDone: clip.active = false }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { clip.active = !clip.active }
    }

    LazyLoader {
        id: power
        PowerMenu { onDone: power.active = false }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { picker.active = !picker.active }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { power.active = !power.active }
        function lock(): void { Quickshell.execDetached(Config.lockCmd()) }
    }
}
