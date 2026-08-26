import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import "MediaModel.js" as MediaModel

BarWidget {
  id: root
  moduleName: "custom.media"

  property var service: null

  // Telemetry properties
  property real tempPeak: 52.0
  property real tempAvg: 48.0
  property real cpuLoad: 1.2
  property real ramPercent: 64.0
  property real ramUsed: 4.7
  property real ramTotal: 7.5
  property string powerProfile: "balanced"
  property bool autoPilotActive: true
  property bool mediaPopupOpen: false
  property bool turboPopupOpen: false

  function close() {
    mediaPopupOpen = false
    turboPopupOpen = false
  }

  readonly property color tempColor: {
    if (tempPeak < 65) return "#10b981" // Cool Green
    if (tempPeak < 80) return "#f59e0b" // Warm Amber
    return "#ef4444"                    // Hot Red
  }

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

  Process {
    id: wallProc
    running: false
  }

  // -------------------------------------------------------------
  // MPRIS MEDIA HANDLING
  // -------------------------------------------------------------
  readonly property var mediaService: {
    if (service) return service
    if (!root.bar || !root.bar.shell) return null
    if (root.moduleName && root.bar.shell.serviceFor(root.moduleName))
      return root.bar.shell.serviceFor(root.moduleName)
    if (root.bar.shell.serviceFor("custom.media"))
      return root.bar.shell.serviceFor("custom.media")
    if (root.bar.shell.firstPartyServiceFor("omarchy.media"))
      return root.bar.shell.firstPartyServiceFor("omarchy.media")
    return null
  }

  function deduplicatePlayers(players) {
    var list = []
    var seen = {}
    var raw = players || []
    for (var i = 0; i < raw.length; i++) {
      var p = raw[i]
      if (!p || MediaModel.isProxyPlayer(p)) continue
      var cKey = MediaModel.playerCanonicalKey(p)
      if (!cKey || seen[cKey]) continue
      seen[cKey] = true
      if (MediaModel.hasMetadata(p)) list.push(p)
    }
    return list
  }

  readonly property var fallbackPlayers: deduplicatePlayers(Mpris.players ? Mpris.players.values : [])

  function findFallbackActivePlayer() {
    var list = fallbackPlayers || []
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (p && p.playbackState === MprisPlaybackState.Playing) return p
    }
    return list.length > 0 ? list[0] : null
  }

  readonly property var activePlayer: {
    if (mediaService && mediaService.activePlayer) return mediaService.activePlayer
    return findFallbackActivePlayer()
  }

  readonly property var sourcePlayers: {
    if (mediaService && mediaService.sourcePlayers && mediaService.sourcePlayers.length > 0)
      return mediaService.sourcePlayers
    return fallbackPlayers
  }

  readonly property bool isPlaying: {
    if (!activePlayer) return false
    if (typeof activePlayer.isPlaying === "boolean") return activePlayer.isPlaying
    if (activePlayer.playbackState !== undefined)
      return activePlayer.playbackState === MprisPlaybackState.Playing
    return false
  }

  readonly property bool hasMedia: {
    if (!activePlayer) return false
    if (typeof activePlayer.hasMedia === "boolean") return activePlayer.hasMedia
    return MediaModel.hasMetadata(activePlayer)
  }

  readonly property string title: {
    if (!activePlayer) return ""
    if (activePlayer.trackTitle) return String(activePlayer.trackTitle)
    if (activePlayer.metadata && activePlayer.metadata["xesam:title"]) return String(activePlayer.metadata["xesam:title"])
    return ""
  }

  readonly property string artist: {
    if (!activePlayer) return ""
    if (activePlayer.trackArtist) return String(activePlayer.trackArtist)
    if (activePlayer.metadata && activePlayer.metadata["xesam:artist"]) {
      var a = activePlayer.metadata["xesam:artist"]
      return Array.isArray(a) ? a.join(", ") : String(a)
    }
    return ""
  }

  readonly property string artUrl: {
    if (mediaService && mediaService.artUrl) return mediaService.artUrl
    if (!activePlayer) return ""
    return MediaModel.extractArtUrl(activePlayer)
  }

  readonly property real positionSec: {
    if (activePlayer && activePlayer.position !== undefined) return activePlayer.position / 1000000.0
    return 0.0
  }

  readonly property real lengthSec: {
    if (activePlayer && activePlayer.length !== undefined) return activePlayer.length / 1000000.0
    if (activePlayer && activePlayer.metadata && activePlayer.metadata["mpris:length"])
      return Number(activePlayer.metadata["mpris:length"]) / 1000000.0
    return 0.0
  }

  function formatTime(sec) {
    if (isNaN(sec) || sec <= 0) return "0:00"
    var m = Math.floor(sec / 60)
    var s = Math.floor(sec % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  function getSourceIcon(identity) {
    var id = (identity || "").toLowerCase()
    if (id.indexOf("spotify") !== -1) return ""
    if (id.indexOf("youtube") !== -1 || id.indexOf("chromium") !== -1 || id.indexOf("chrome") !== -1) return ""
    if (id.indexOf("firefox") !== -1 || id.indexOf("zen") !== -1) return "󰈹"
    if (id.indexOf("vlc") !== -1) return "󰕼"
    if (id.indexOf("mpv") !== -1) return ""
    return "󰝚"
  }

  property real eqPhase: 0.0
  NumberAnimation on eqPhase {
    running: root.isPlaying && root.visible
    from: 0.0
    to: Math.PI * 2.0
    duration: 1200
    loops: Animation.Infinite
  }

  // -------------------------------------------------------------
  // TOP BAR CONTAINER: Spotify (Auto-Wake) + Turbo HUD + Theme
  // -------------------------------------------------------------
  visible: true
  implicitWidth: masterRow.implicitWidth + Style.space(4)
  implicitHeight: barSize

  Row {
    id: masterRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    // 1. Spotify Audio Capsule (Auto-Wakes on Play, Sleeps when Stopped)
    Rectangle {
      id: mediaCapsule
      anchors.verticalCenter: parent.verticalCenter
      height: Math.min(parent.height - Style.space(6), Style.space(28))
      implicitWidth: mediaInner.implicitWidth + Style.space(14)
      radius: height / 2
      color: mediaMouse.containsMouse ? "#201db954" : (root.isPlaying ? "#141db954" : "#12151c")
      border.color: root.isPlaying ? "#1db954" : (mediaMouse.containsMouse ? "#1db95488" : "#2a3447")
      border.width: 1
      visible: root.hasMedia

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: mediaInner
        anchors.centerIn: parent
        spacing: Style.space(6)

        // Spotify Icon
        Rectangle {
          width: Style.space(16)
          height: Style.space(16)
          radius: width / 2
          color: root.isPlaying ? "#1db954" : "#2a2e39"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: root.getSourceIcon(root.activePlayer ? root.activePlayer.identity : "")
            color: root.isPlaying ? "#000000" : "#8a94a6"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 10
            font.bold: true
          }
        }

        // 4-Bar Equalizer
        Row {
          spacing: Style.space(1.5)
          anchors.verticalCenter: parent.verticalCenter
          visible: root.isPlaying

          Repeater {
            model: 4
            Rectangle {
              required property int index
              width: Style.space(2)
              height: Style.space(3) + Math.abs(Math.sin(root.eqPhase * 1.8 + index * 0.9)) * Style.space(8)
              radius: 1
              color: "#1db954"
              anchors.bottom: parent.bottom
            }
          }
        }

        // Track Title
        Text {
          text: root.title
          color: root.isPlaying ? "#ffffff" : "#94a3b8"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: root.isPlaying
          elide: Text.ElideRight
          maximumLineCount: 1
          width: Math.min(implicitWidth, 140)
          anchors.verticalCenter: parent.verticalCenter
        }

        // Artist
        Text {
          text: root.artist ? "· " + root.artist : ""
          color: "#1db954"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          visible: root.artist !== ""
          width: Math.min(implicitWidth, 80)
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        id: mediaMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            root.turboPopupOpen = false
            root.mediaPopupOpen = !root.mediaPopupOpen
          } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
            if (root.mediaService && root.activePlayer) {
              root.mediaService.runAction("playPause", false, MediaModel.playerKey(root.activePlayer))
            } else if (root.activePlayer && typeof root.activePlayer.togglePlaying === "function") {
              root.activePlayer.togglePlaying()
            }
          }
        }

        onWheel: (wheel) => {
          if (!root.activePlayer) return
          if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
          else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
        }
      }
    }

    // 2. ⚡ Omarchy Turbo Telemetry Pill (ALWAYS VISIBLE on Bar)
    Rectangle {
      id: turboCapsule
      anchors.verticalCenter: parent.verticalCenter
      height: Math.min(parent.height - Style.space(6), Style.space(28))
      implicitWidth: turboInner.implicitWidth + Style.space(16)
      radius: height / 2
      color: turboMouse.containsMouse ? "#2510b981" : "#131722"
      border.color: root.tempColor
      border.width: 1

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: turboInner
        anchors.centerIn: parent
        spacing: Style.space(6)

        // CPU Temperature
        Row {
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: root.tempPeak >= 78 ? "🔥" : (root.tempPeak >= 65 ? "⚡" : "❄️")
            font.pixelSize: 10
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

        Rectangle {
          width: 1
          height: Style.space(10)
          color: "#2a3447"
          anchors.verticalCenter: parent.verticalCenter
        }

        // RAM Usage
        Row {
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "🧠"
            font.pixelSize: 10
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
        id: turboMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.mediaPopupOpen = false
          root.turboPopupOpen = !root.turboPopupOpen
        }
      }
    }

    // 3. 🎨 Theme & Wallpaper Rotator Button
    Rectangle {
      id: themeCapsule
      anchors.verticalCenter: parent.verticalCenter
      height: Math.min(parent.height - Style.space(6), Style.space(28))
      implicitWidth: themeInner.implicitWidth + Style.space(12)
      radius: height / 2
      color: themeMouse.containsMouse ? "#253b82f6" : "#131722"
      border.color: themeMouse.containsMouse ? "#3b82f6" : "#2a3447"
      border.width: 1

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: themeInner
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          text: "🎨"
          font.pixelSize: 11
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "Theme"
          color: themeMouse.containsMouse ? "#60a5fa" : "#94a3b8"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
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

  // -------------------------------------------------------------
  // POPUP 1: SPOTIFY GLASS PLAYER CARD & 1-CLICK TAB SWITCHER
  // -------------------------------------------------------------
  PopupCard {
    id: mediaPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.mediaPopupOpen
    contentWidth: mediaPopup.fittedContentWidth(Style.space(350))
    contentHeight: mediaPopup.fittedContentHeight(mediaDeck.implicitHeight + Style.space(20))

    Column {
      id: mediaDeck
      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(12)

      // Header
      Item {
        width: parent.width
        height: Style.space(20)

        Row {
          spacing: Style.space(6)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: ""
            color: "#1db954"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "SPOTIFY GLASS AUDIO HUB"
            color: "#1db954"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(64)
          height: Style.space(20)
          radius: 10
          color: root.isPlaying ? "#1db95425" : "#33415530"
          border.color: root.isPlaying ? "#1db954" : "#475569"

          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "PLAYING" : "PAUSED"
            color: root.isPlaying ? "#1db954" : "#94a3b8"
            font.pixelSize: 8
            font.bold: true
          }
        }
      }

      // Album Cover & Title
      Row {
        spacing: Style.space(14)
        width: parent.width

        Rectangle {
          width: Style.space(80)
          height: Style.space(80)
          radius: 12
          color: "#181818"
          border.color: "#1db95455"
          border.width: 1

          Image {
            anchors.fill: parent
            anchors.margins: 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.artUrl
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: ""
            color: "#1db954"
            font.pixelSize: 36
          }
        }

        Column {
          width: parent.width - Style.space(98)
          spacing: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: root.hasMedia ? root.title : "No Media Playing"
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.hasMedia && root.artist ? root.artist : "Ready to play audio"
            color: "#cbd5e1"
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width
          }

          Row {
            spacing: Style.space(4)
            visible: root.hasMedia

            Rectangle {
              height: Style.space(18)
              implicitWidth: sourceTagText.implicitWidth + Style.space(12)
              radius: 9
              color: "#1e293b"

              Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                  text: root.getSourceIcon(root.activePlayer ? root.activePlayer.identity : "")
                  color: "#1db954"
                  font.pixelSize: 10
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: sourceTagText
                  text: root.activePlayer ? (root.activePlayer.identity || "Media Source") : "Audio"
                  color: "#94a3b8"
                  font.pixelSize: 9
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }
        }
      }

      // Progress Bar
      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.hasMedia

        Rectangle {
          width: parent.width
          height: 4
          radius: 2
          color: "#282828"

          Rectangle {
            width: root.lengthSec > 0 ? parent.width * Math.min(1.0, root.positionSec / root.lengthSec) : (root.isPlaying ? parent.width * 0.4 : 0)
            height: parent.height
            radius: 2
            color: "#1db954"
          }
        }

        Item {
          width: parent.width
          height: Style.space(14)
          Text {
            text: root.formatTime(root.positionSec)
            color: "#64748b"
            font.pixelSize: 10
            anchors.left: parent.left
          }
          Text {
            text: root.formatTime(root.lengthSec)
            color: "#64748b"
            font.pixelSize: 10
            anchors.right: parent.right
          }
        }
      }

      // Playback Controls (Prev, Big Play/Pause FAB, Next)
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(16)
        visible: root.hasMedia

        Rectangle {
          width: Style.space(38)
          height: Style.space(38)
          radius: 19
          color: prevMouse.containsMouse ? "#2a303c" : "#1e2430"
          border.color: "#334155"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "󰒮"
            color: "#ffffff"
            font.pixelSize: 15
          }
          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.mediaService) root.mediaService.runAction("previous", false)
          }
        }

        Rectangle {
          width: Style.space(50)
          height: Style.space(50)
          radius: 25
          color: playMouse.containsMouse ? "#1ed760" : "#1db954"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "󰏤" : "󰐊"
            color: "#000000"
            font.pixelSize: 22
            font.bold: true
          }
          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.mediaService && root.activePlayer) {
                root.mediaService.runAction("playPause", false, MediaModel.playerKey(root.activePlayer))
              } else if (root.activePlayer && typeof root.activePlayer.togglePlaying === "function") {
                root.activePlayer.togglePlaying()
              }
            }
          }
        }

        Rectangle {
          width: Style.space(38)
          height: Style.space(38)
          radius: 19
          color: nextMouse.containsMouse ? "#2a303c" : "#1e2430"
          border.color: "#334155"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "󰒭"
            color: "#ffffff"
            font.pixelSize: 15
          }
          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.mediaService) root.mediaService.runAction("next", false)
          }
        }
      }

      // 1-Click Multi-Tab Audio Switcher
      Column {
        id: tabSourceList
        width: parent.width
        spacing: Style.space(6)
        visible: root.sourcePlayers && root.sourcePlayers.length > 0

        Rectangle {
          width: parent.width
          height: 1
          color: "#1e293b"
        }

        Row {
          spacing: 6
          Text {
            text: "󱘖"
            color: "#1db954"
            font.pixelSize: 11
          }
          Text {
            text: "ACTIVE TABS & PLAYERS (" + root.sourcePlayers.length + ")"
            color: "#94a3b8"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.0
          }
        }

        Repeater {
          model: root.sourcePlayers

          Rectangle {
            id: tabRow
            required property var modelData
            readonly property var pItem: modelData
            readonly property bool isSelected: root.activePlayer && pItem
              && MediaModel.playerKey(root.activePlayer) === MediaModel.playerKey(pItem)
            readonly property bool isThisPlaying: pItem && (pItem.isPlaying || pItem.playbackState === MprisPlaybackState.Playing)

            width: tabSourceList.width
            height: Style.space(40)
            radius: 8
            color: isSelected ? "#1db95420" : (rowMouse.containsMouse ? "#1e293b80" : "#111620")
            border.color: isSelected ? "#1db954" : (rowMouse.containsMouse ? "#334155" : "#1e293b")
            border.width: 1

            Row {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: Style.space(8)

              Text {
                text: root.getSourceIcon(tabRow.pItem ? tabRow.pItem.identity : "")
                color: tabRow.isSelected ? "#1db954" : "#94a3b8"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(72)
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: tabRow.pItem ? (tabRow.pItem.trackTitle || tabRow.pItem.identity || "Media Tab") : "Active Tab"
                  color: tabRow.isSelected ? "#ffffff" : "#cbd5e1"
                  font.pixelSize: 11
                  font.bold: tabRow.isSelected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: tabRow.pItem && tabRow.pItem.trackArtist ? tabRow.pItem.trackArtist : (tabRow.pItem ? (tabRow.pItem.identity || "Browser Audio") : "Ready")
                  color: "#64748b"
                  font.pixelSize: 9
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              // Direct 1-Click Play/Pause on this Tab
              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: 13
                color: tabRow.isThisPlaying ? "#1db954" : "#334155"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: tabRow.isThisPlaying ? "󰏤" : "󰐊"
                  color: tabRow.isThisPlaying ? "#000000" : "#ffffff"
                  font.pixelSize: 10
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.mediaService && tabRow.pItem) {
                      root.mediaService.runAction("playPause", false, MediaModel.playerKey(tabRow.pItem))
                    }
                  }
                }
              }
            }

            // Direct 1-Click switch to this tab
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.mediaService && tabRow.pItem) {
                  root.mediaService.selectPlayer(MediaModel.playerKey(tabRow.pItem))
                }
              }
            }
          }
        }
      }
    }
  }

  // -------------------------------------------------------------
  // POPUP 2: ⚡ OMARCHY TURBO TELEMETRY HUD & POWER CONTROL
  // -------------------------------------------------------------
  PopupCard {
    id: turboPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.turboPopupOpen
    contentWidth: turboPopup.fittedContentWidth(Style.space(330))
    contentHeight: turboPopup.fittedContentHeight(turboHudCol.implicitHeight + Style.space(20))

    Column {
      id: turboHudCol
      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(12)

      // Header Row
      Item {
        width: parent.width
        height: Style.space(20)

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
            color: root.powerProfile === "performance" ? "#ef4444" : (root.powerProfile === "power-saver" ? "#10b981" : "#3b82f6")
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
            Text { text: "PEAK TEMP"; color: "#6b7280"; font.pixelSize: 8; font.bold: true }
            Text { text: root.tempPeak + "°C"; color: root.tempColor; font.pixelSize: 15; font.bold: true }
          }

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "AVG TEMP"; color: "#6b7280"; font.pixelSize: 8; font.bold: true }
            Text { text: root.tempAvg + "°C"; color: "#e5e7eb"; font.pixelSize: 15; font.bold: true }
          }

          Column {
            width: parent.width / 3
            spacing: 2
            Text { text: "CPU LOAD"; color: "#6b7280"; font.pixelSize: 8; font.bold: true }
            Text { text: root.cpuLoad; color: root.cpuLoad > 3.0 ? "#f59e0b" : "#10b981"; font.pixelSize: 15; font.bold: true }
          }
        }
      }

      // Memory (RAM) Bar
      Column {
        width: parent.width
        spacing: 4

        Item {
          width: parent.width
          height: Style.space(16)
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

        Item {
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
