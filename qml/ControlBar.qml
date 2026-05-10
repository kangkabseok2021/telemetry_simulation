import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UAV 1.0

Rectangle {
    id: root
    implicitHeight: 44
    color: "#0b1520"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Button {
            id: startBtn
            text: "▶ START SIMULATION"
            enabled: !Drone.isRunning
            onClicked: Drone.start()
            background: Rectangle {
                color: startBtn.down ? "#0a2a10" : "#0f3d1a"
                border.color: "#2aff2a"
                border.width: 1
                radius: 4
                opacity: startBtn.enabled ? 1.0 : 0.4
            }
            contentItem: Text {
                text: startBtn.text
                color: "#2aff2a"
                font.pixelSize: 11
                font.family: "Courier New"
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: startBtn.enabled ? 1.0 : 0.4
            }
        }

        Button {
            id: stopBtn
            text: "■ STOP"
            enabled: Drone.isRunning
            onClicked: Drone.stop()
            background: Rectangle {
                color: stopBtn.down ? "#2a0a0a" : "#3d0f0f"
                border.color: "#ff4444"
                border.width: 1
                radius: 4
                opacity: stopBtn.enabled ? 1.0 : 0.4
            }
            contentItem: Text {
                text: stopBtn.text
                color: "#ff4444"
                font.pixelSize: 11
                font.family: "Courier New"
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: stopBtn.enabled ? 1.0 : 0.4
            }
        }

        Button {
            id: emergencyBtn
            text: "⚠ EMERGENCY"
            onClicked: Drone.triggerEmergency()
            background: Rectangle {
                color: emergencyBtn.down ? "#2a1a00" : "#3d2008"
                border.color: "#ff9500"
                border.width: 1
                radius: 4
            }
            contentItem: Text {
                text: emergencyBtn.text
                color: "#ff9500"
                font.pixelSize: 11
                font.family: "Courier New"
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "UPDATE RATE: 50ms"
            color: "#4a9eff"
            font.pixelSize: 10
            font.family: "Courier New"
        }

        Text {
            id: simTimerLabel
            property int seconds: 0
            text: "SIM TIME: " + Qt.formatTime(new Date(seconds * 1000), "mm:ss")
            color: "#8a9bb0"
            font.pixelSize: 10
            font.family: "Courier New"

            Timer {
                interval: 1000
                running: Drone.isRunning
                repeat: true
                onTriggered: simTimerLabel.seconds++
            }

            Connections {
                target: Drone
                function onEmergencyTriggered() { simTimerLabel.seconds = 0 }
            }
        }
    }
}
