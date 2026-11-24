import QtQuick
import Quickshell.Io

// Process + collecte de la sortie standard, avec un signal done(texte).
Process {
    id: root
    signal done(string text)
    stdout: StdioCollector {
        onStreamFinished: root.done(text)
    }
}
