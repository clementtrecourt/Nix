import QtQuick
import Quickshell.Io

// Commande dont on veut toute la sortie standard (signal done(text)).
Process {
    id: root
    signal done(string text)
    stdout: StdioCollector { onStreamFinished: root.done(text) }
}
