import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "custom.turbo"

  property real tempPeak: 52.0
  property real tempAvg: 48.0
  property real cpuLoad: 1.2
  property real ramPercent: 64.0
  property real ramUsed: 4.7
  property real ramTotal: 7.5
  property string powerProfile: "balanced"
  property bool autoPilotActive: true
  property bool popupOpen: false

  function close() { popupOpen = false }

  readonly property color tempColor: {
    if (tempPeak < 65) return "#10b981" // Cool Green
    if (tempPeak < 80) return "#f59e0b" // Warm Amber
    return "#ef4444"                    // Hot Red
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
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text.trim())
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

  visible: true
  implicitWidth: turboPill.implicitWidth
  implicitHeight: barSize

  Rectangle {
    id: turboPill
    anchors.verticalCenter: parent.verticalCenter
    height: Math.min(parent.height - Style.space(6), Style.space(28))
    implicitWidth: pillRow.implicitWidth + Style.space(16)
    radius: height / 2
    color: barArea.containsMouse ? "#2510b981" : "#131722"
    border.color: root.tempColor
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: 300 } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      // CPU Temp
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: root.tempPeak >= 78 ? "🔥" : (root.tempPeak >= 65 ? "⚡" : "❄️")
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: Math.round(root.tempPeak) + "°C"
          color: root.tempColor
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // Divider
      Rectangle {
        width: 1
        height: Style.space(10)
        color: "#2a3447"
        anchors.verticalCenter: parent.verticalCenter
      }

      // RAM Usage
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: "🧠"
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: Math.round(root.ramPercent) + "%"
          color: root.ramPercent > 85 ? "#ef4444" : "#cbd5e1"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    MouseArea {
      id: barArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.popupOpen = !root.popupOpen
    }
  }

  // Floating Turbo HUD Popup Card
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(hudColumn.implicitHeight + Style.space(20))

    Column {
      id: hudColumn
      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(12)

      // Header Row
      Row {
        width: parent.width

        Row {
          spacing: 6
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "⚡"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
          }
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
          width: Style.space(80)
          height: Style.space(20)
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
        height: Style.space(64)
        radius: 10
        color: "#111827"
        border.color: "#1f2937"

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(10)

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "PEAK TEMP"; color: "#6b7280"; font.pixelSize: 9; font.bold: true }
            Text { text: root.tempPeak + "°C"; color: root.tempColor; font.pixelSize: 15; font.bold: true }
          }

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "AVG TEMP"; color: "#6b7280"; font.pixelSize: 9; font.bold: true }
            Text { text: root.tempAvg + "°C"; color: "#e5e7eb"; font.pixelSize: 15; font.bold: true }
          }

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "CPU LOAD"; color: "#6b7280"; font.pixelSize: 9; font.bold: true }
            Text { text: root.cpuLoad; color: root.cpuLoad > 3.0 ? "#f59e0b" : "#10b981"; font.pixelSize: 15; font.bold: true }
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
            font.pixelSize: 10
            font.bold: true
            anchors.left: parent.left
          }
          Text {
            text: root.ramUsed + " / " + root.ramTotal + " GB (" + root.ramPercent + "%)"
            color: "#e5e7eb"
            font.pixelSize: 10
            anchors.right: parent.right
          }
        }

        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: "#1f2937"

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
        spacing: Style.space(6)

        Text {
          text: "🚀 QUICK ACTIONS"
          color: "#6b7280"
          font.pixelSize: 9
          font.bold: true
          font.letterSpacing: 1.0
        }

        Row {
          spacing: Style.space(6)
          width: parent.width

          Rectangle {
            width: (parent.width - Style.space(12)) / 3
            height: Style.space(32)
            radius: 6
            color: coolBtn.containsMouse ? "#10b98130" : "#1f2937"
            border.color: "#10b981"

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "❄️"; font.pixelSize: 11 }
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
            width: (parent.width - Style.space(12)) / 3
            height: Style.space(32)
            radius: 6
            color: boostBtn.containsMouse ? "#ef444430" : "#1f2937"
            border.color: "#ef4444"

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "🚀"; font.pixelSize: 11 }
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
            width: (parent.width - Style.space(12)) / 3
            height: Style.space(32)
            radius: 6
            color: cleanBtn.containsMouse ? "#3b82f630" : "#1f2937"
            border.color: "#3b82f6"

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "🧹"; font.pixelSize: 11 }
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
        height: Style.space(34)
        radius: 8
        color: "#111827"
        border.color: root.autoPilotActive ? "#10b98155" : "#374151"

        Row {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10

          Row {
            spacing: 6
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: root.autoPilotActive ? "🤖" : "⏸"
              font.pixelSize: 12
            }
            Text {
              text: root.autoPilotActive ? "Auto-Pilot Active" : "Auto-Pilot Paused"
              color: root.autoPilotActive ? "#10b981" : "#9ca3af"
              font.pixelSize: 10
              font.bold: true
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(48)
            height: Style.space(20)
            radius: 10
            color: root.autoPilotActive ? "#10b981" : "#4b5563"

            Text {
              anchors.centerIn: parent
              text: root.autoPilotActive ? "ON" : "OFF"
              color: "#000000"
              font.pixelSize: 9
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
