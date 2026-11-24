import QtQuick
import QtQuick.Shapes

// Disque « Multicolor » (roue de couleurs) de la pastille d'accent.
Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillGradient: ConicalGradient {
            centerX: 11; centerY: 11; angle: 90
            GradientStop { position: 0.00; color: "#FF3B30" }
            GradientStop { position: 0.17; color: "#FF9500" }
            GradientStop { position: 0.33; color: "#FFCC00" }
            GradientStop { position: 0.50; color: "#34C759" }
            GradientStop { position: 0.67; color: "#007AFF" }
            GradientStop { position: 0.83; color: "#AF52DE" }
            GradientStop { position: 1.00; color: "#FF3B30" }
        }
        PathAngleArc { centerX: 11; centerY: 11; radiusX: 11; radiusY: 11; startAngle: 0; sweepAngle: 360 }
    }
}
