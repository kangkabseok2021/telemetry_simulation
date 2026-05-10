import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UAV 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 720
    minimumWidth: 900
    minimumHeight: 600
    title: "UAV Telemetry & Simulation Control Station"
    color: "#080d14"

    // ── Root container using anchors (avoids ColumnLayout implicit-size issue) ──
    Item {
        anchors.fill: parent

        // ── Status bar ─────────────────────────────────────
        Rectangle {
            id: statusBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 32; color: "#0b1520"

            RowLayout {
                anchors { fill: parent; margins: 10 }
                spacing: 10

                Rectangle { width: 8; height: 8; radius: 4; color: "#00e5ff" }

                Text {
                    text: "UAV CONTROL STATION"
                    color: "#4a9eff"
                    font.pixelSize: 11; font.letterSpacing: 2; font.bold: true; font.family: "Courier New"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "MISSION: WAYPOINT ROUTE A"
                    color: "#4aff91"
                    font.pixelSize: 10; font.family: "Courier New"
                }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Drone.isRunning ? "#ff4500" : "#444444"
                }

                Text {
                    text: Drone.isRunning ? "LIVE" : "IDLE"
                    color: Drone.isRunning ? "#ff4500" : "#444444"
                    font.pixelSize: 10; font.letterSpacing: 1; font.family: "Courier New"
                }
            }
        }

        Rectangle {
            id: topSep
            anchors { top: statusBar.bottom; left: parent.left; right: parent.right }
            height: 1; color: "#1a3050"
        }

        // ── Control bar (anchor to bottom first so main area fills the rest) ──
        ControlBar {
            id: controlBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        }

        Rectangle {
            id: bottomSep
            anchors { bottom: controlBar.top; left: parent.left; right: parent.right }
            height: 1; color: "#1a3050"
        }

        // ── Main 3-column area ─────────────────────────────
        RowLayout {
            id: mainRow
            anchors {
                top: topSep.bottom; bottom: bottomSep.top
                left: parent.left; right: parent.right
                margins: 8
            }
            spacing: 8

            // Left column: attitude dials
            ColumnLayout {
                spacing: 8
                Layout.preferredWidth: 140
                Layout.maximumWidth: 140
                Layout.fillHeight: true

                Text {
                    text: "ATTITUDE"
                    color: "#4a9eff"
                    font.pixelSize: 9; font.letterSpacing: 2; font.family: "Courier New"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true; height: 1; color: "#1a3050"
                    Layout.bottomMargin: 2
                }

                AttitudeDial { label: "PITCH";   mode: "horizon";  value: Drone.pitch; Layout.alignment: Qt.AlignHCenter }
                AttitudeDial { label: "ROLL";    mode: "horizon";  value: Drone.roll;  Layout.alignment: Qt.AlignHCenter }
                AttitudeDial { label: "HEADING"; mode: "compass";  value: Drone.yaw;   Layout.alignment: Qt.AlignHCenter }

                Item { Layout.fillHeight: true }
            }

            // Center: GPS map
            MapPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Right: telemetry readout
            TelemetryReadout {
                Layout.preferredWidth: 185
                Layout.maximumWidth: 185
                Layout.fillHeight: true
            }
        }
    }

    // ── Emergency overlay ───────────────────────────────────
    Rectangle {
        id: emergencyOverlay
        anchors.fill: parent
        color: "#70ff0000"
        visible: false
        z: 100

        Column {
            anchors.centerIn: parent
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⚠  EMERGENCY PROTOCOL ACTIVATED"
                color: "#ffffff"
                font.pixelSize: 26; font.bold: true; font.family: "Courier New"; font.letterSpacing: 2
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Click anywhere to dismiss"
                color: "#99ffffff"
                font.pixelSize: 13; font.family: "Courier New"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: emergencyOverlay.visible = false
        }

        Connections {
            target: Drone
            function onEmergencyTriggered() { emergencyOverlay.visible = true }
        }
    }
}
