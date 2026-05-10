import QtQuick
import QtQuick.Layouts
import UAV 1.0

ColumnLayout {
    id: root
    spacing: 6
    width: 180

    Text {
        text: "TELEMETRY"
        color: "#4a9eff"
        font.pixelSize: 9
        font.letterSpacing: 2
        font.family: "Courier New"
        Layout.alignment: Qt.AlignHCenter
    }

    // ── Altitude ────────────────────────────────────────────
    Rectangle {
        color: "#0d1a2e"
        border.color: "#1a3050"
        border.width: 1
        radius: 6
        Layout.fillWidth: true
        implicitHeight: 68

        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 2
            Text { text: "ALTITUDE"; color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New" }
            Text { text: Drone.altitude.toFixed(0); color: "#00e5ff"; font.pixelSize: 22; font.bold: true; font.family: "Courier New" }
            Text { text: "meters"; color: "#4a9eff"; font.pixelSize: 9; font.family: "Courier New" }
            Rectangle {
                width: parent.width; height: 3; color: "#0a1525"; radius: 2
                Rectangle {
                    width: Math.max(0, Math.min(parent.width * Drone.altitude / 200.0, parent.width))
                    height: parent.height; color: "#00e5ff"; radius: 2
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Speed ───────────────────────────────────────────────
    Rectangle {
        color: "#0d1a2e"; border.color: "#1a3050"; border.width: 1; radius: 6
        Layout.fillWidth: true; implicitHeight: 68
        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 2
            Text { text: "SPEED"; color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New" }
            Text { text: Drone.speed.toFixed(0); color: "#4aff91"; font.pixelSize: 22; font.bold: true; font.family: "Courier New" }
            Text { text: "km/h"; color: "#4a9eff"; font.pixelSize: 9; font.family: "Courier New" }
            Rectangle {
                width: parent.width; height: 3; color: "#0a1525"; radius: 2
                Rectangle {
                    width: Math.max(0, Math.min(parent.width * Drone.speed / 100.0, parent.width))
                    height: parent.height; color: "#4aff91"; radius: 2
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Battery ─────────────────────────────────────────────
    Rectangle {
        color: "#0d1a2e"; border.color: "#1a3050"; border.width: 1; radius: 6
        Layout.fillWidth: true; implicitHeight: 72
        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 4
            Text { text: "BATTERY"; color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New" }
            Text {
                text: Drone.battery.toFixed(0) + "%"
                color: Drone.battery > 50 ? "#ffd700" : (Drone.battery > 20 ? "#ff9500" : "#ff4444")
                font.pixelSize: 22; font.bold: true; font.family: "Courier New"
            }
            Rectangle {
                width: parent.width; height: 8; color: "#0a1525"; radius: 3
                border.color: "#2a4060"; border.width: 1
                Rectangle {
                    width: Math.max(0, Math.min(parent.width * Drone.battery / 100.0, parent.width))
                    height: parent.height
                    color: Drone.battery > 50 ? "#ffd700" : (Drone.battery > 20 ? "#ff9500" : "#ff4444")
                    radius: 3
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Altitude Sparkline ───────────────────────────────────
    Rectangle {
        color: "#0d1a2e"; border.color: "#1a3050"; border.width: 1; radius: 6
        Layout.fillWidth: true; implicitHeight: 60

        Text {
            anchors { top: parent.top; left: parent.left; topMargin: 6; leftMargin: 8 }
            text: "ALT HISTORY"
            color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New"
        }

        Canvas {
            id: sparkline
            anchors { fill: parent; topMargin: 18; margins: 8 }
            property var samples: []

            Connections {
                target: Drone
                function onTelemetryChanged() {
                    sparkline.samples.push(Drone.altitude)
                    if (sparkline.samples.length > 60) sparkline.samples.shift()
                    sparkline.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "#0a1525"
                ctx.fillRect(0, 0, width, height)

                if (samples.length < 2) return

                var maxAlt = 200.0, minAlt = 0.0
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth = 1.5
                ctx.beginPath()
                for (var i = 0; i < samples.length; i++) {
                    var x = (i / (samples.length - 1)) * width
                    var y = height - ((samples[i] - minAlt) / (maxAlt - minAlt)) * height
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()

                // Current dot
                var lx = width
                var ly = height - ((samples[samples.length - 1] - minAlt) / (maxAlt - minAlt)) * height
                ctx.fillStyle = "#00e5ff"
                ctx.beginPath()
                ctx.arc(lx, ly, 2.5, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    Item { Layout.fillHeight: true }
}
