import QtQuick
import UAV 1.0

Rectangle {
    id: root
    color: "#0d1a2e"
    border.color: "#1a3050"
    border.width: 1
    radius: 6
    clip: true

    // ── Header ────────────────────────────────────────────────
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 26; color: "transparent"

        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: "GPS TRACK"; color: "#4a9eff"; font.pixelSize: 9; font.letterSpacing: 2; font.family: "Courier New" }
        }
        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: "LAT " + Drone.latitude.toFixed(4) + "°"; color: "#8a9bb0"; font.pixelSize: 9; font.family: "Courier New" }
            Text { text: "LON " + Drone.longitude.toFixed(4) + "°"; color: "#8a9bb0"; font.pixelSize: 9; font.family: "Courier New" }
        }
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: "#1a3050"
        }
    }

    // ── Map Canvas ────────────────────────────────────────────
    Canvas {
        id: mapCanvas
        anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 4 }

        // Bounding box matching the hardcoded waypoints in WaypointManager
        readonly property double minLat:  37.7700
        readonly property double maxLat:  37.8350
        readonly property double minLon: -122.4350
        readonly property double maxLon: -122.3550

        function lonToX(lon) {
            return (lon - minLon) / (maxLon - minLon) * width  * 0.86 + width  * 0.07
        }
        function latToY(lat) {
            return height - ((lat - minLat) / (maxLat - minLat) * height * 0.86 + height * 0.07)
        }

        Component.onCompleted: Qt.callLater(requestPaint)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: Drone
            function onTelemetryChanged() { mapCanvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Background
            ctx.fillStyle = "#0a1525"
            ctx.fillRect(0, 0, width, height)

            // Grid
            ctx.strokeStyle = "#1a3050"
            ctx.lineWidth = 0.5
            for (var i = 1; i < 4; i++) {
                ctx.beginPath(); ctx.moveTo(width * i / 4, 0); ctx.lineTo(width * i / 4, height); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke()
            }

            var route = Drone.plannedRoute
            var trail = Drone.breadcrumbs

            // ── Planned route (dashed) ────────────────────────
            if (route.length > 1) {
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth = 1
                ctx.setLineDash([5, 4])
                ctx.globalAlpha = 0.35
                ctx.beginPath()
                for (var r = 0; r < route.length; r++) {
                    var rx = lonToX(route[r].lon), ry = latToY(route[r].lat)
                    if (r === 0) ctx.moveTo(rx, ry); else ctx.lineTo(rx, ry)
                }
                // Close loop back to first
                ctx.lineTo(lonToX(route[0].lon), latToY(route[0].lat))
                ctx.stroke()
                ctx.setLineDash([])
                ctx.globalAlpha = 1.0

                // Waypoint markers
                for (var w = 0; w < route.length; w++) {
                    var wx = lonToX(route[w].lon), wy = latToY(route[w].lat)
                    ctx.strokeStyle = "#2a5080"; ctx.lineWidth = 1.5
                    ctx.beginPath(); ctx.arc(wx, wy, 4, 0, Math.PI * 2); ctx.stroke()
                }

                // Start marker (green)
                ctx.fillStyle = "#4aff91"
                ctx.beginPath(); ctx.arc(lonToX(route[0].lon), latToY(route[0].lat), 5, 0, Math.PI * 2); ctx.fill()
            }

            // ── Completed breadcrumb trail ────────────────────
            if (trail.length > 1) {
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth = 2
                ctx.setLineDash([])
                ctx.beginPath()
                for (var b = 0; b < trail.length; b++) {
                    var bx = lonToX(trail[b].lon), by = latToY(trail[b].lat)
                    if (b === 0) ctx.moveTo(bx, by); else ctx.lineTo(bx, by)
                }
                ctx.stroke()
            }

            // ── Drone marker ──────────────────────────────────
            var dx = lonToX(Drone.longitude), dy = latToY(Drone.latitude)
            var headRad = (Drone.yaw - 90) * Math.PI / 180

            // Heading arrow
            ctx.strokeStyle = "#00e5ff"; ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(dx, dy)
            ctx.lineTo(dx + Math.cos(headRad) * 16, dy + Math.sin(headRad) * 16)
            ctx.stroke()

            // Glow ring
            ctx.fillStyle = "rgba(0, 229, 255, 0.15)"
            ctx.beginPath(); ctx.arc(dx, dy, 10, 0, Math.PI * 2); ctx.fill()

            // Drone dot
            ctx.fillStyle = "#00e5ff"
            ctx.beginPath(); ctx.arc(dx, dy, 5, 0, Math.PI * 2); ctx.fill()
        }
    }
}
