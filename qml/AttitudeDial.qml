import QtQuick
import UAV 1.0

Item {
    id: root
    property double value: 0.0
    property string mode: "horizon"   // "horizon" or "compass"
    property string label: "DIAL"

    implicitWidth: 120
    implicitHeight: 140

    Text {
        id: labelText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        text: root.label
        color: "#8a9bb0"
        font.pixelSize: 9; font.letterSpacing: 1; font.family: "Courier New"
    }

    Canvas {
        id: dialCanvas
        anchors { top: labelText.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        width: 90; height: 90

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.mode === "horizon") drawHorizon(ctx)
            else drawCompass(ctx)
        }

        function drawHorizon(ctx) {
            var cx = width / 2, cy = height / 2, r = width / 2 - 2

            // Clip to circle
            ctx.save()
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.clip()

            // Rotate for attitude value
            ctx.translate(cx, cy)
            ctx.rotate(root.value * Math.PI / 180)
            ctx.translate(-cx, -cy)

            // Sky and ground
            ctx.fillStyle = "#1a3a5c"
            ctx.fillRect(0, 0, width, cy)
            ctx.fillStyle = "#3d2008"
            ctx.fillRect(0, cy, width, height)

            // Horizon line
            ctx.strokeStyle = "#ffd700"
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(0, cy)
            ctx.lineTo(width, cy)
            ctx.stroke()

            ctx.restore()

            // Fixed aircraft symbol (unrotated)
            ctx.strokeStyle = "#ffffff"
            ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.moveTo(cx - 20, cy); ctx.lineTo(cx - 8, cy); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx + 8,  cy); ctx.lineTo(cx + 20, cy); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, cy - 6); ctx.lineTo(cx, cy + 6); ctx.stroke()

            // Outer ring
            ctx.strokeStyle = "#1a3050"
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.stroke()

            // Centre dot
            ctx.fillStyle = "#00e5ff"
            ctx.beginPath(); ctx.arc(cx, cy, 2, 0, Math.PI * 2); ctx.fill()
        }

        function drawCompass(ctx) {
            var cx = width / 2, cy = height / 2, r = width / 2 - 2

            // Background circle
            ctx.fillStyle = "#0a1525"
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill()

            // Outer ring
            ctx.strokeStyle = "#1a3050"
            ctx.lineWidth = 2
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()

            // Cardinal labels
            var cardinals = [
                ["N",   0, "#ff4444"],
                ["E",  90, "#8a9bb0"],
                ["S", 180, "#8a9bb0"],
                ["W", 270, "#8a9bb0"]
            ]
            ctx.font = "8px 'Courier New'"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            for (var i = 0; i < cardinals.length; i++) {
                var ang = (cardinals[i][1] - 90) * Math.PI / 180
                ctx.fillStyle = cardinals[i][2]
                ctx.fillText(cardinals[i][0],
                    cx + (r - 10) * Math.cos(ang),
                    cy + (r - 10) * Math.sin(ang))
            }

            // Needle (rotated to heading)
            var needleAng = (root.value - 90) * Math.PI / 180
            var tipX  = cx + (r - 18) * Math.cos(needleAng)
            var tipY  = cy + (r - 18) * Math.sin(needleAng)
            var tailX = cx + (r - 18) * Math.cos(needleAng + Math.PI)
            var tailY = cy + (r - 18) * Math.sin(needleAng + Math.PI)

            ctx.strokeStyle = "#ff4444"; ctx.lineWidth = 2
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(tipX, tipY); ctx.stroke()
            ctx.strokeStyle = "#4a9eff"; ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(tailX, tailY); ctx.stroke()

            ctx.fillStyle = "#00e5ff"
            ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.fill()
        }
    }

    Text {
        anchors { top: dialCanvas.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        text: root.value.toFixed(1) + "°"
        color: "#00e5ff"
        font.pixelSize: 13; font.bold: true; font.family: "Courier New"
    }

    Connections {
        target: Drone
        function onTelemetryChanged() { dialCanvas.requestPaint() }
    }
}
