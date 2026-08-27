import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "custom.chef-hud"

  property int securityScore: 88
  property string firewallStatus: "Ready"
  property int listeningPortsCount: 8
  property bool popupOpen: false

  function close() { popupOpen = false }

  visible: true
  implicitWidth: barPill.implicitWidth
  implicitHeight: barSize

  // 1. Telemetry Poller
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!auditTelemetryProc.running) auditTelemetryProc.running = true
    }
  }

  Process {
    id: auditTelemetryProc
    command: ["ss", "-tuln"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var lines = text.trim().split("\n")
          if (lines.length > 1) {
            root.listeningPortsCount = lines.length - 1
          }
        } catch(e) {}
      }
    }
  }

  // 2. Launch helper process
  Process {
    id: launchProc
    running: false
  }

  function launchTerminalCommand(cmd) {
    launchProc.command = ["alacritty", "-e", "bash", "-c", cmd + "; echo ''; read -n 1 -s -r -p 'Press any key to close...';"]
    launchProc.running = true
    root.popupOpen = false
  }

  // --- Top Bar Pill Widget ---
  Rectangle {
    id: barPill
    anchors.verticalCenter: parent.verticalCenter
    height: Math.min(parent.height - Style.space(4), Style.space(26))
    implicitWidth: pillRow.implicitWidth + Style.space(16)
    radius: Style.radius(4)
    color: pillMouse.containsMouse || root.popupOpen ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.background, 0.6)
    border.color: pillMouse.containsMouse || root.popupOpen ? Color.accent : Util.alpha(Color.foreground, 0.18)
    border.width: 1

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Text {
        text: "🛡️"
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: "Cyber"
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 1
        height: Style.space(10)
        color: Util.alpha(Color.foreground, 0.2)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.securityScore + "%"
        color: root.securityScore > 80 ? "#10b981" : "#f59e0b"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.popupOpen = !root.popupOpen
    }
  }

  // --- Floating Chef_Carthy Cyber HUD PopupCard ---
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(hudCol.implicitHeight + Style.space(20))

    Column {
      id: hudCol
      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(10)

      // Header Row
      Row {
        width: parent.width

        Row {
          spacing: Style.space(6)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          Text { text: "🛡️"; font.pixelSize: 13 }
          Text {
            text: "CHEF_CARTHY CYBER HUD"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.1
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Hardened Status Badge
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(60)
          height: Style.space(16)
          radius: 8
          color: Util.alpha("#10b981", 0.2)
          border.color: "#10b981"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "HARDENED"
            color: "#10b981"
            font.pixelSize: 7
            font.bold: true
          }
        }
      }

      // Security Score & Telemetry Card
      Rectangle {
        width: parent.width
        height: Style.space(58)
        radius: 8
        color: Util.alpha(Color.background, 0.6)
        border.color: Util.alpha(Color.foreground, 0.12)
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(10)

          // Circular Score Metric
          Rectangle {
            width: Style.space(42)
            height: Style.space(42)
            radius: width / 2
            color: Util.alpha("#10b981", 0.15)
            border.color: "#10b981"
            border.width: 2
            anchors.verticalCenter: parent.verticalCenter

            Column {
              anchors.centerIn: parent
              spacing: 0
              Text {
                text: root.securityScore + "%"
                color: "#10b981"
                font.pixelSize: 11
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }
              Text {
                text: "SCORE"
                color: Color.muted
                font.pixelSize: 5
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }

          // System Stats Breakdown
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            width: parent.width - Style.space(56)

            Row {
              spacing: 4
              Text { text: "🔒 Kernel Security:"; color: Color.muted; font.pixelSize: 7 }
              Text { text: "dmesg / kptr Restrict Active"; color: "#10b981"; font.pixelSize: 7; font.bold: true }
            }

            Row {
              spacing: 4
              Text { text: "🌐 Open Sockets:"; color: Color.muted; font.pixelSize: 7 }
              Text { text: root.listeningPortsCount + " Local Listeners (ss)"; color: Color.accent; font.pixelSize: 7; font.bold: true }
            }

            Row {
              spacing: 4
              Text { text: "🤖 AI Defense Core:"; color: Color.muted; font.pixelSize: 7 }
              Text { text: "Autonomous Agentic Engine"; color: Color.foreground; font.pixelSize: 7 }
            }
          }
        }
      }

      // Quick Launch Security Operations Grid
      Text {
        text: "⚡ AUTONOMOUS AI SECURITY OPERATIONS"
        color: Color.muted
        font.pixelSize: 7
        font.bold: true
        font.letterSpacing: 0.8
      }

      // 1. AI Security Audit Action Button
      Rectangle {
        width: parent.width
        height: Style.space(26)
        radius: 6
        color: btn1Mouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.background, 0.7)
        border.color: btn1Mouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.2)
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)
          Text { text: "🔍"; font.pixelSize: 9 }
          Text {
            text: "Run Autonomous Security Audit (chef audit)"
            color: Color.foreground
            font.pixelSize: 7
            font.bold: true
          }
        }

        MouseArea {
          id: btn1Mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.launchTerminalCommand("chef audit")
        }
      }

      // 2. Interactive AI Assistant Prompt
      Rectangle {
        width: parent.width
        height: Style.space(26)
        radius: 6
        color: btn2Mouse.containsMouse ? Util.alpha("#8b5cf6", 0.3) : Util.alpha(Color.background, 0.7)
        border.color: btn2Mouse.containsMouse ? "#8b5cf6" : Util.alpha(Color.foreground, 0.2)
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)
          Text { text: "🤖"; font.pixelSize: 9 }
          Text {
            text: "Ask Chef_Carthy AI Security Assistant"
            color: Color.foreground
            font.pixelSize: 7
            font.bold: true
          }
        }

        MouseArea {
          id: btn2Mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.launchTerminalCommand("chef ai")
        }
      }

      // 3. Network Inspection & Tools Catalog Row
      Row {
        width: parent.width
        spacing: Style.space(6)

        Rectangle {
          width: (hudCol.width - Style.space(6)) / 2
          height: Style.space(24)
          radius: 6
          color: btn3Mouse.containsMouse ? Util.alpha(Color.foreground, 0.15) : Util.alpha(Color.foreground, 0.05)
          border.color: Util.alpha(Color.foreground, 0.1)

          Row {
            anchors.centerIn: parent
            spacing: 3
            Text { text: "🌐"; font.pixelSize: 7 }
            Text { text: "Network Scan"; color: Color.foreground; font.pixelSize: 7; font.bold: true }
          }

          MouseArea {
            id: btn3Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchTerminalCommand("chef network")
          }
        }

        Rectangle {
          width: (hudCol.width - Style.space(6)) / 2
          height: Style.space(24)
          radius: 6
          color: btn4Mouse.containsMouse ? Util.alpha(Color.foreground, 0.15) : Util.alpha(Color.foreground, 0.05)
          border.color: Util.alpha(Color.foreground, 0.1)

          Row {
            anchors.centerIn: parent
            spacing: 3
            Text { text: "🧰"; font.pixelSize: 7 }
            Text { text: "Security Tools"; color: Color.foreground; font.pixelSize: 7; font.bold: true }
          }

          MouseArea {
            id: btn4Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchTerminalCommand("chef tools list")
          }
        }
      }
    }
  }
}
