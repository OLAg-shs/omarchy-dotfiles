import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons

Item {
  id: root

  // -------------------------------------------------------------
  // HARDWARE TELEMETRY PROPERTIES
  // -------------------------------------------------------------
  property real tempPeak: 52.0
  property real tempAvg: 48.0
  property real cpuLoad: 1.2
  property real ramPercent: 64.0
  property real ramUsed: 4.7
  property real ramTotal: 7.5
  property string powerProfile: "balanced"
  property bool autoPilotActive: true

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

  Process {
    id: hudProc
    running: false
  }

  Process {
    id: wallProc
    running: false
  }

  // -------------------------------------------------------------
  // SPOTIFY GLASS AUDIO & EQUALIZER INTEGRATION
  // -------------------------------------------------------------
  readonly property var activePlayer: {
    var list = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].playbackState === MprisPlaybackState.Playing) return list[i]
    }
    return list.length > 0 ? list[0] : null
  }

  readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
  readonly property bool hasMedia: activePlayer && activePlayer.trackTitle !== undefined && activePlayer.trackTitle !== ""

  readonly property string trackTitle: hasMedia ? String(activePlayer.trackTitle) : ""
  readonly property string trackArtist: (activePlayer && activePlayer.trackArtist) ? String(activePlayer.trackArtist) : ""

  property real eqPhase: 0.0
  NumberAnimation on eqPhase {
    running: root.isPlaying
    from: 0.0
    to: Math.PI * 2.0
    duration: 1200
    loops: Animation.Infinite
  }

  implicitWidth: mainRow.implicitWidth
  implicitHeight: 28
  width: implicitWidth
  height: implicitHeight

  Row {
    id: mainRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    // 1. 🎵 SPOTIFY GLASS AUDIO CAPSULE (Glowing Emerald + Dancing EQ Bars)
    Rectangle {
      id: spotifyCapsule
      anchors.verticalCenter: parent.verticalCenter
      height: 26
      implicitHeight: 26
      implicitWidth: spotifyInner.implicitWidth + 14
      width: implicitWidth
      radius: 13
      color: spotifyMouse.containsMouse ? "#251db954" : (root.isPlaying ? "#161db954" : "#12151c")
      border.color: root.isPlaying ? "#1db954" : (spotifyMouse.containsMouse ? "#1db95488" : "#2a3447")
      border.width: 1
      visible: root.hasMedia

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: spotifyInner
        anchors.centerIn: parent
        spacing: 5

        // Spotify Disc
        Rectangle {
          width: 16
          height: 16
          radius: 8
          color: root.isPlaying ? "#1db954" : "#2a2e39"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: ""
            color: root.isPlaying ? "#000000" : "#8a94a6"
            font.pixelSize: 10
            font.bold: true
          }
        }

        // 4-Bar Equalizer
        Row {
          spacing: 1.5
          anchors.verticalCenter: parent.verticalCenter
          visible: root.isPlaying

          Repeater {
            model: 4
            Rectangle {
              required property int index
              width: 2
              height: 3 + Math.abs(Math.sin(root.eqPhase * 1.8 + index * 0.9)) * 8
              radius: 1
              color: "#1db954"
              anchors.bottom: parent.bottom
            }
          }
        }

        // Track Title
        Text {
          text: root.trackTitle
          color: root.isPlaying ? "#ffffff" : "#94a3b8"
          font.pixelSize: 11
          font.bold: root.isPlaying
          elide: Text.ElideRight
          maximumLineCount: 1
          width: Math.min(implicitWidth, 140)
          anchors.verticalCenter: parent.verticalCenter
        }

        // Artist
        Text {
          text: root.trackArtist ? "· " + root.trackArtist : ""
          color: "#1db954"
          font.pixelSize: 10
          elide: Text.ElideRight
          visible: root.trackArtist !== ""
          width: Math.min(implicitWidth, 80)
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        id: spotifyMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            hudProc.command = ["chromium", "--app=http://localhost:3000"]
            hudProc.running = true
          } else if (mouse.button === Qt.RightButton) {
            if (root.activePlayer && typeof root.activePlayer.togglePlaying === "function") {
              root.activePlayer.togglePlaying()
            }
          }
        }
      }
    }

    // 2. ⚡ LIVE TURBO TELEMETRY PILL (Click opens Turbo Center GUI)
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
        onClicked: {
          hudProc.command = ["/home/chef_carthy/.local/bin/omarchy-turbo-gui"]
          hudProc.running = true
        }
      }
    }

    // 3. 🎨 THEME & WALLPAPER CYCLER BUTTON
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
}
