import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property real tempPeak: 52.0
  property real tempAvg: 48.0
  property real cpuLoad: 1.2
  property real ramPercent: 64.0
  property real ramUsed: 4.7
  property real ramTotal: 7.5
  property string powerProfile: "balanced"
  property bool autoPilotActive: true
  property bool popupOpen: false

  readonly property color tempColor: {
    if (tempPeak < 65) return "#10b981"
    if (tempPeak < 80) return "#f59e0b"
    return "#ef4444"
  }

  // Poll hardware metrics every 3 seconds
  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: telemetryProc.running = true
  }

  Process {
    id: telemetryProc
    command: ["/home/chef_carthy/.local/bin/omarchy-turbo", "--json"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line.trim())
          root.tempPeak = data.temp_peak
          root.tempAvg = data.temp_avg
          root.cpuLoad = data.load_1m
          root.ramPercent = data.ram_percent
          root.ramUsed = data.ram_used
          root.ramTotal = data.ram_total
          root.powerProfile = data.power_profile
          root.autoPilotActive = data.auto_pilot
        } catch(e) {}
      }
    }
  }

  function runTurboAction(action) {
    actionProc.command = ["/home/chef_carthy/.local/bin/omarchy-turbo", action]
    actionProc.running = true
    refreshTimer.start()
  }

  Timer {
    id: refreshTimer
    interval: 600
    repeat: false
    onTriggered: telemetryProc.running = true
  }

  Process {
    id: actionProc
    running: false
  }

  Process {
    id: wallProc
    running: false
  }

  implicitWidth: mainRow.implicitWidth
  implicitHeight: 28
  width: implicitWidth
  height: implicitHeight

  Row {
    id: mainRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    // 1. ⚡ Live Turbo Telemetry Pill (ALWAYS VISIBLE on Bar)
    Rectangle {
      id: turboPill
      anchors.verticalCenter: parent.verticalCenter
      height: 26
      implicitHeight: 26
      implicitWidth: pillRow.implicitWidth + 16
      width: implicitWidth
      radius: 13
      color: turboMouse.containsMouse ? "#2510b981" : "#131722"
      border.color: root.tempColor
      border.width: 1

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 6

        // CPU Temp
        Row {
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: root.tempPeak >= 78 ? "🔥" : (root.tempPeak >= 65 ? "⚡" : "❄️")
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: Math.round(root.tempPeak) + "°C"
            color: root.tempColor
            font.pixelSize: 11
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          width: 1
          height: 10
          color: "#2a3447"
          anchors.verticalCenter: parent.verticalCenter
        }

        // RAM Usage
        Row {
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "🧠"
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: Math.round(root.ramPercent) + "%"
            color: root.ramPercent > 85 ? "#ef4444" : "#cbd5e1"
            font.pixelSize: 11
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      MouseArea {
        id: turboMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popupOpen = !root.popupOpen
      }
    }

    // 2. 🎨 Theme Cycler Button
    Rectangle {
      id: themeBtn
      anchors.verticalCenter: parent.verticalCenter
      height: 26
      implicitHeight: 26
      implicitWidth: themeRow.implicitWidth + 14
      width: implicitWidth
      radius: 13
      color: themeMouse.containsMouse ? "#253b82f6" : "#131722"
      border.color: themeMouse.containsMouse ? "#3b82f6" : "#2a3447"
      border.width: 1

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: themeRow
        anchors.centerIn: parent
        spacing: 4

        Text {
          text: "🎨"
          font.pixelSize: 11
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "Theme"
          color: themeMouse.containsMouse ? "#60a5fa" : "#94a3b8"
          font.pixelSize: 11
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        id: themeMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            wallProc.command = ["/home/chef_carthy/.local/bin/omarchy-walltheme", "auto", "next"]
            wallProc.running = true
          } else if (mouse.button === Qt.RightButton) {
            wallProc.command = ["omarchy", "theme", "bg-switcher"]
            wallProc.running = true
          }
        }
      }
    }
  }

  // Floating Turbo HUD Popup
  Rectangle {
    id: hudCard
    visible: root.popupOpen
    x: 0
    y: 34
    width: 320
    height: hudColumn.implicitHeight + 24
    radius: 12
    color: "#0f131a"
    border.color: "#1f293d"
    border.width: 1
    z: 9999

    Column {
      id: hudColumn
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      // Header Row
      Row {
        width: parent.width

        Row {
          spacing: 6
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          Text { text: "⚡"; font.pixelSize: 14 }
          Text {
            text: "OMARCHY TURBO HUD"
            color: "#10b981"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.2
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 80
          height: 20
          radius: 10
          color: root.powerProfile === "performance" ? "#ef444425" : (root.powerProfile === "power-saver" ? "#10b98125" : "#3b82f625")
          border.color: root.powerProfile === "performance" ? "#ef4444" : (root.powerProfile === "power-saver" ? "#10b981" : "#3b82f6")

          Text {
            anchors.centerIn: parent
            text: root.powerProfile.toUpperCase()
            color: parent.border.color
            font.pixelSize: 8
            font.bold: true
          }
        }
      }

      // Thermal & CPU Health Card
      Rectangle {
        width: parent.width
        height: 60
        radius: 8
        color: "#141924"
        border.color: "#1e293b"

        Row {
          anchors.fill: parent
          anchors.margins: 8

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "PEAK TEMP"; color: "#6b7280"; font.pixelSize: 8; font.bold: true }
            Text { text: root.tempPeak + "°C"; color: root.tempColor; font.pixelSize: 14; font.bold: true }
          }

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "AVG TEMP"; color: "#6b7280"; font.pixelSize: 8; font.bold: true }
            Text { text: root.tempAvg + "°C"; color: "#e5e7eb"; font.pixelSize: 14; font.bold: true }
          }

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "CPU LOAD"; color: "#6b7280"; font.pixelSize: 8; font.bold: true }
            Text { text: root.cpuLoad; color: root.cpuLoad > 3.0 ? "#f59e0b" : "#10b981"; font.pixelSize: 14; font.bold: true }
          }
        }
      }

      // Memory (RAM) Bar
      Column {
        width: parent.width
        spacing: 4

        Row {
          width: parent.width
          Text {
            text: "🧠 SYSTEM MEMORY (RAM)"
            color: "#9ca3af"
            font.pixelSize: 9
            font.bold: true
            anchors.left: parent.left
          }
          Text {
            text: root.ramUsed + " / " + root.ramTotal + " GB (" + root.ramPercent + "%)"
            color: "#e5e7eb"
            font.pixelSize: 9
            anchors.right: parent.right
          }
        }

        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: "#1e293b"

          Rectangle {
            width: parent.width * Math.min(1.0, root.ramPercent / 100.0)
            height: parent.height
            radius: 3
            color: root.ramPercent > 85 ? "#ef4444" : (root.ramPercent > 70 ? "#f59e0b" : "#10b981")
          }
        }
      }

      // Quick Actions Row
      Column {
        width: parent.width
        spacing: 6

        Text {
          text: "🚀 QUICK ACTIONS"
          color: "#6b7280"
          font.pixelSize: 8
          font.bold: true
          font.letterSpacing: 1.0
        }

        Row {
          spacing: 6
          width: parent.width

          Rectangle {
            width: (parent.width - 12) / 3
            height: 30
            radius: 6
            color: coolBtn.containsMouse ? "#10b98130" : "#192231"
            border.color: "#10b981"

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "❄️"; font.pixelSize: 10 }
              Text { text: "Cool"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
            }
            MouseArea {
              id: coolBtn
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runTurboAction("cool")
            }
          }

          Rectangle {
            width: (parent.width - 12) / 3
            height: 30
            radius: 6
            color: boostBtn.containsMouse ? "#ef444430" : "#192231"
            border.color: "#ef4444"

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "🚀"; font.pixelSize: 10 }
              Text { text: "Boost"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
            }
            MouseArea {
              id: boostBtn
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runTurboAction("boost")
            }
          }

          Rectangle {
            width: (parent.width - 12) / 3
            height: 30
            radius: 6
            color: cleanBtn.containsMouse ? "#3b82f630" : "#192231"
            border.color: "#3b82f6"

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "🧹"; font.pixelSize: 10 }
              Text { text: "Clean"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
            }
            MouseArea {
              id: cleanBtn
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runTurboAction("clean")
            }
          }
        }
      }

      // Auto-Pilot Toggle Row
      Rectangle {
        width: parent.width
        height: 32
        radius: 6
        color: "#141924"
        border.color: root.autoPilotActive ? "#10b98155" : "#374151"

        Row {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8

          Row {
            spacing: 6
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: root.autoPilotActive ? "🤖" : "⏸"
              font.pixelSize: 11
            }
            Text {
              text: root.autoPilotActive ? "Auto-Pilot Active" : "Auto-Pilot Paused"
              color: root.autoPilotActive ? "#10b981" : "#9ca3af"
              font.pixelSize: 9
              font.bold: true
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 18
            radius: 9
            color: root.autoPilotActive ? "#10b981" : "#4b5563"

            Text {
              anchors.centerIn: parent
              text: root.autoPilotActive ? "ON" : "OFF"
              color: "#000000"
              font.pixelSize: 8
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.autoPilotActive) {
                  root.runTurboAction("auto stop")
                } else {
                  root.runTurboAction("auto start")
                }
              }
            }
          }
        }
      }
    }
  }
}
