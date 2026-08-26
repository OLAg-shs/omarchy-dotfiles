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

  Process {
    id: playerctlProc
    running: false
  }

  property real livePosition: 0.0
  property real liveDuration: 0.0
  property string liveTitle: ""
  property string liveArtist: ""
  property string liveArtUrl: ""
  property var livePlayers: []
  property string manualSelectedPlayerKey: ""
  property string manualSelectedPlayerName: ""

  function refreshPosProc() {
    var cmd = ["/home/chef_carthy/.local/bin/playerctl"]
    if (root.manualSelectedPlayerName) {
      cmd.push("-p")
      cmd.push(root.manualSelectedPlayerName)
    }
    cmd.push("--json")
    posProc.command = cmd
    posProc.running = true
  }

  function togglePlay() {
    var cmd = ["/home/chef_carthy/.local/bin/playerctl"]
    if (root.manualSelectedPlayerName) {
      cmd.push("-p")
      cmd.push(root.manualSelectedPlayerName)
    }
    cmd.push("play-pause")
    playerctlProc.command = cmd
    playerctlProc.running = true
    posPollTimer.restart()
  }

  function skipNext() {
    var cmd = ["/home/chef_carthy/.local/bin/playerctl"]
    if (root.manualSelectedPlayerName) {
      cmd.push("-p")
      cmd.push(root.manualSelectedPlayerName)
    }
    cmd.push("next")
    playerctlProc.command = cmd
    playerctlProc.running = true
    posPollTimer.restart()
  }

  function skipPrev() {
    var cmd = ["/home/chef_carthy/.local/bin/playerctl"]
    if (root.manualSelectedPlayerName) {
      cmd.push("-p")
      cmd.push(root.manualSelectedPlayerName)
    }
    cmd.push("previous")
    playerctlProc.command = cmd
    playerctlProc.running = true
    posPollTimer.restart()
  }

  Timer {
    id: posPollTimer
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!posProc.running) root.refreshPosProc()
  }

  Process {
    id: posProc
    command: ["/home/chef_carthy/.local/bin/playerctl", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text.trim())
          if (data.active) {
            root.livePosition = data.active.position || 0.0
            root.liveDuration = data.active.length || 0.0
            root.liveTitle = data.active.title || ""
            root.liveArtist = data.active.artist || ""
            root.liveArtUrl = data.active.artUrl || ""
          }
          if (data.players) {
            root.livePlayers = data.players
          }
        } catch(e) {}
      }
    }
  }

  // Smooth local ticker
  Timer {
    interval: 1000
    running: root.isPlaying
    repeat: true
    onTriggered: {
      if (root.livePosition < root.liveDuration || root.liveDuration <= 0) {
        root.livePosition += 1.0
      }
    }
  }

  function seekOffset(seconds) {
    root.livePosition = Math.max(0.0, root.livePosition + seconds)
    var cmd = ["/home/chef_carthy/.local/bin/playerctl"]
    if (root.manualSelectedPlayerName) {
      cmd.push("-p")
      cmd.push(root.manualSelectedPlayerName)
    }
    cmd.push("position")
    cmd.push(String(seconds))
    playerctlProc.command = cmd
    playerctlProc.running = true
    posPollTimer.restart()
  }

  function seekTo(targetSeconds) {
    root.livePosition = targetSeconds
    var cmd = ["/home/chef_carthy/.local/bin/playerctl"]
    if (root.manualSelectedPlayerName) {
      cmd.push("-p")
      cmd.push(root.manualSelectedPlayerName)
    }
    cmd.push("set-position")
    cmd.push(String(targetSeconds))
    playerctlProc.command = cmd
    playerctlProc.running = true
    posPollTimer.restart()
  }

  IpcHandler {
    target: "custom.media"

    function toggle(): void {
      root.turboPopupOpen = false
      root.mediaPopupOpen = !root.mediaPopupOpen
    }

    function open(): void {
      root.turboPopupOpen = false
      root.mediaPopupOpen = true
    }

    function close(): void {
      root.mediaPopupOpen = false
    }

    function playPause(): void {
      root.togglePlay()
    }

    function next(): void {
      root.skipNext()
    }

    function previous(): void {
      root.skipPrev()
    }
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
    if (root.manualSelectedPlayerKey) {
      for (var k = 0; k < list.length; k++) {
        if (MediaModel.playerKey(list[k]) === root.manualSelectedPlayerKey) return list[k]
      }
    }
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (p && p.playbackState === MprisPlaybackState.Playing) return p
    }
    return list.length > 0 ? list[0] : null
  }

  readonly property var activePlayer: {
    if (root.manualSelectedPlayerKey && mediaService) {
      var mp = mediaService.playerForKey(root.manualSelectedPlayerKey)
      if (mp) return mp
    }
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
    if (!activePlayer) return root.liveTitle !== ""
    if (typeof activePlayer.hasMedia === "boolean") return activePlayer.hasMedia
    return MediaModel.hasMetadata(activePlayer) || root.liveTitle !== ""
  }

  readonly property string title: {
    if (activePlayer && activePlayer.trackTitle) return String(activePlayer.trackTitle)
    if (activePlayer && activePlayer.metadata && activePlayer.metadata["xesam:title"]) return String(activePlayer.metadata["xesam:title"])
    if (root.liveTitle) return root.liveTitle
    return ""
  }

  readonly property string artist: {
    if (activePlayer && activePlayer.trackArtist) return String(activePlayer.trackArtist)
    if (activePlayer && activePlayer.metadata && activePlayer.metadata["xesam:artist"]) {
      var a = activePlayer.metadata["xesam:artist"]
      return Array.isArray(a) ? a.join(", ") : String(a)
    }
    if (root.liveArtist) return root.liveArtist
    return ""
  }

  readonly property string artUrl: {
    if (mediaService && mediaService.artUrl) return mediaService.artUrl
    if (activePlayer) {
      var u = MediaModel.extractArtUrl(activePlayer)
      if (u) return u
    }
    if (root.liveArtUrl) return root.liveArtUrl
    return ""
  }

  readonly property real positionSec: {
    if (root.livePosition > 0) return root.livePosition
    if (activePlayer && activePlayer.position !== undefined && activePlayer.position > 0) return activePlayer.position / 1000000.0
    return 0.0
  }

  readonly property real lengthSec: {
    if (root.liveDuration > 0) return root.liveDuration
    if (activePlayer && activePlayer.length !== undefined && activePlayer.length > 0) return activePlayer.length / 1000000.0
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
      color: root.isPlaying ? "#141db954" : "#12151c"
      border.color: root.isPlaying ? "#1db954" : "#2a3447"
      border.width: 1
      visible: root.hasMedia

      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on border.color { ColorAnimation { duration: 200 } }

      Row {
        id: mediaInner
        anchors.centerIn: parent
        spacing: Style.space(6)

        // 1. Main Info Area (Icon + Equalizer + Title + Artist) - Click opens popup
        Item {
          id: mediaInfoArea
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: mediaInfoRow.implicitWidth
          implicitHeight: mediaInfoRow.implicitHeight

          Row {
            id: mediaInfoRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(5)

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

            // 4-Bar Dancing Equalizer
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
              width: Math.min(implicitWidth, 135)
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
              width: Math.min(implicitWidth, 75)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            id: mediaInfoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.turboPopupOpen = false
              root.mediaPopupOpen = !root.mediaPopupOpen
            }
            onWheel: (wheel) => {
              if (wheel.angleDelta.y > 0) root.seekOffset(5)
              else if (wheel.angleDelta.y < 0) root.seekOffset(-5)
            }
          }
        }

        // Subtle Divider
        Rectangle {
          width: 1
          height: Style.space(10)
          color: "#2a3447"
          anchors.verticalCenter: parent.verticalCenter
        }

        // 2. Clickable Inline Control Buttons
        Row {
          id: inlineButtons
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          // Prev Button
          Rectangle {
            width: Style.space(16)
            height: Style.space(16)
            radius: width / 2
            color: prevInlineMouse.containsMouse ? "#251db954" : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: "⏮"
              color: prevInlineMouse.containsMouse ? "#1db954" : "#94a3b8"
              font.pixelSize: 8
            }

            MouseArea {
              id: prevInlineMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.skipPrev()
            }
          }

          // Play / Pause Button
          Rectangle {
            width: Style.space(18)
            height: Style.space(18)
            radius: width / 2
            color: playInlineMouse.containsMouse ? "#1ed760" : "#1db954"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: root.isPlaying ? "⏸" : "▶"
              color: "#000000"
              font.pixelSize: 8
              font.bold: true
            }

            MouseArea {
              id: playInlineMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePlay()
            }
          }

          // Next Button
          Rectangle {
            width: Style.space(16)
            height: Style.space(16)
            radius: width / 2
            color: nextInlineMouse.containsMouse ? "#251db954" : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: "⏭"
              color: nextInlineMouse.containsMouse ? "#1db954" : "#94a3b8"
              font.pixelSize: 8
            }

            MouseArea {
              id: nextInlineMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.skipNext()
            }
          }
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            wallProc.command = ["/usr/share/omarchy/bin/omarchy-theme-switcher"]
            wallProc.running = true
          } else if (mouse.button === Qt.RightButton) {
            wallProc.command = ["omarchy", "theme", "bg-switcher"]
            wallProc.running = true
          } else if (mouse.button === Qt.MiddleButton) {
            wallProc.command = ["/home/chef_carthy/.local/bin/omarchy-theme-cycle"]
            wallProc.running = true
          }
        }

        onWheel: (wheel) => {
          wallProc.command = ["/home/chef_carthy/.local/bin/omarchy-theme-cycle"]
          wallProc.running = true
        }
      }
    }
  }

  // -------------------------------------------------------------
  // POPUP 1: SPOTIFY PREMIUM GLASS AUDIO HUB & SOURCE SWITCHER
  // -------------------------------------------------------------
  PopupCard {
    id: mediaPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.mediaPopupOpen
    contentWidth: mediaPopup.fittedContentWidth(Style.space(350))
    contentHeight: mediaPopup.fittedContentHeight(mediaDeck.implicitHeight + Style.space(24))

    // Premium Spotify Vertical Gradient Background
    Rectangle {
      anchors.fill: parent
      radius: 16
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#222a38" }
        GradientStop { position: 0.35; color: "#141722" }
        GradientStop { position: 1.0; color: "#0c0f16" }
      }
      border.color: "#1db95433"
      border.width: 1
    }

    Column {
      id: mediaDeck
      anchors.fill: parent
      anchors.margins: Style.space(14)
      spacing: Style.space(12)

      // 1. Header (Branding & Live Status)
      Item {
        width: parent.width
        height: Style.space(22)

        Row {
          spacing: Style.space(6)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: ""
            color: "#1db954"
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "SPOTIFY AUDIO HUB"
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
          height: Style.space(20)
          implicitWidth: statusText.implicitWidth + Style.space(14)
          radius: 10
          color: root.isPlaying ? "#1db95420" : "#33415525"
          border.color: root.isPlaying ? "#1db954" : "#475569"
          border.width: 1

          Row {
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
              width: 6
              height: 6
              radius: 3
              color: root.isPlaying ? "#1db954" : "#64748b"
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: statusText
              text: root.isPlaying ? "PLAYING" : "PAUSED"
              color: root.isPlaying ? "#1db954" : "#94a3b8"
              font.pixelSize: 8
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // 2. Album Artwork & Track Info (Spotify Hierarchy)
      Row {
        spacing: Style.space(14)
        width: parent.width

        // Album Art with rounded corners and subtle shadow/depth
        Rectangle {
          width: Style.space(76)
          height: Style.space(76)
          radius: 10
          color: "#141720"
          border.color: "#ffffff18"
          border.width: 1

          Image {
            anchors.fill: parent
            anchors.margins: 1
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
            font.pixelSize: 32
          }
        }

        // Title & Artist Column
        Column {
          width: parent.width - Style.space(92)
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          // Track Title (Bold & Prominent)
          Text {
            text: root.hasMedia ? root.title : "No Media Playing"
            color: "#ffffff"
            font.pixelSize: 15
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          // Artist (Secondary, Dimmer & Regular Weight)
          Text {
            text: root.hasMedia && root.artist ? root.artist : "Ready to play audio"
            color: "#a1a1aa"
            font.pixelSize: 12
            font.bold: false
            elide: Text.ElideRight
            width: parent.width
          }

          // Media Source Pill Badge
          Row {
            spacing: Style.space(4)
            visible: root.hasMedia

            Rectangle {
              height: Style.space(18)
              implicitWidth: sourceTagText.implicitWidth + Style.space(12)
              radius: 9
              color: "#18202d"
              border.color: "#283548"
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                  text: root.getSourceIcon(root.manualSelectedPlayerName || (root.activePlayer ? root.activePlayer.identity : ""))
                  color: "#1db954"
                  font.pixelSize: 9
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: sourceTagText
                  text: root.manualSelectedPlayerName || (root.activePlayer ? (root.activePlayer.identity || "Media Source") : "Audio")
                  color: "#71717a"
                  font.pixelSize: 9
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }
        }
      }

      // 3. Spotify Progress & Seek Bar
      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.hasMedia

        Item {
          width: parent.width
          height: 14

          Rectangle {
            id: progressBarTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: (progressMouse.containsMouse || progressMouse.pressed) ? 6 : 4
            radius: height / 2
            color: "#282828"

            Behavior on height { NumberAnimation { duration: 120 } }

            Rectangle {
              id: progressFill
              width: root.lengthSec > 0 ? parent.width * Math.min(1.0, root.positionSec / root.lengthSec) : (root.isPlaying ? parent.width * 0.4 : 0)
              height: parent.height
              radius: parent.radius
              color: (progressMouse.containsMouse || progressMouse.pressed) ? "#1ed760" : "#1db954"
            }
          }

          // Circular Scrubber Knob
          Rectangle {
            id: scrubberKnob
            width: 12
            height: 12
            radius: 6
            color: "#ffffff"
            border.color: "#00000033"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, (root.lengthSec > 0 ? parent.width * Math.min(1.0, root.positionSec / root.lengthSec) : 0) - width / 2))
            visible: progressMouse.containsMouse || progressMouse.pressed
          }

          MouseArea {
            id: progressMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function handleSeek(mouseX) {
              if (root.lengthSec > 0) {
                var pct = Math.max(0.0, Math.min(1.0, mouseX / width))
                root.seekTo(pct * root.lengthSec)
              }
            }

            onClicked: (mouse) => handleSeek(mouse.x)
            onPositionChanged: (mouse) => {
              if (pressed) handleSeek(mouse.x)
            }
            onWheel: (wheel) => {
              if (wheel.angleDelta.y > 0) root.seekOffset(5)
              else if (wheel.angleDelta.y < 0) root.seekOffset(-5)
            }
          }
        }

        // Live Elapsed & Total Timestamps
        Item {
          width: parent.width
          height: Style.space(14)

          Text {
            text: root.formatTime(root.positionSec)
            color: "#94a3b8"
            font.pixelSize: 10
            anchors.left: parent.left
          }
          Text {
            text: root.formatTime(root.lengthSec)
            color: "#94a3b8"
            font.pixelSize: 10
            anchors.right: parent.right
          }
        }
      }

      // 4. Cohesive Playback Control Cluster (Tightened Grouping)
      Rectangle {
        width: Style.space(140)
        height: Style.space(46)
        radius: 23
        color: "#141924"
        border.color: "#222c3c"
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.hasMedia

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          // Previous Track
          Rectangle {
            width: Style.space(32)
            height: Style.space(32)
            radius: 16
            color: prevMouse.containsMouse ? "#242f40" : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: "⏮"
              color: prevMouse.containsMouse ? "#1db954" : "#cbd5e1"
              font.pixelSize: 13
            }
            MouseArea {
              id: prevMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.skipPrev()
            }
          }

          // Center Big Play/Pause FAB
          Rectangle {
            width: Style.space(40)
            height: Style.space(40)
            radius: 20
            color: playMouse.containsMouse ? "#1ed760" : "#1db954"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: root.isPlaying ? "⏸" : "▶"
              color: "#000000"
              font.pixelSize: 15
              font.bold: true
            }
            MouseArea {
              id: playMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePlay()
            }
          }

          // Next Track
          Rectangle {
            width: Style.space(32)
            height: Style.space(32)
            radius: 16
            color: nextMouse.containsMouse ? "#242f40" : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: "⏭"
              color: nextMouse.containsMouse ? "#1db954" : "#cbd5e1"
              font.pixelSize: 13
            }
            MouseArea {
              id: nextMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.skipNext()
            }
          }
        }
      }

      // 5. 1-Click Multi-Tab & Multi-Player Audio Switcher
      Column {
        id: tabSourceList
        width: parent.width
        spacing: Style.space(6)
        visible: (root.livePlayers && root.livePlayers.length > 0) || (root.sourcePlayers && root.sourcePlayers.length > 0)

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
            text: "ACTIVE TABS & PLAYERS (" + (root.livePlayers.length > 0 ? root.livePlayers.length : (root.sourcePlayers ? root.sourcePlayers.length : 0)) + ")"
            color: "#94a3b8"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.0
          }
        }

        Repeater {
          model: root.livePlayers.length > 0 ? root.livePlayers : root.sourcePlayers

          Rectangle {
            id: tabRow
            required property var modelData
            readonly property var pItem: modelData
            readonly property string pName: pItem ? (pItem.name || MediaModel.playerKey(pItem) || "") : ""
            readonly property string pTitle: pItem ? (pItem.title || pItem.trackTitle || pName || "Audio Tab") : "Media"
            readonly property string pArtist: pItem ? (pItem.artist || pItem.trackArtist || pName || "") : ""
            readonly property bool isSelected: (root.manualSelectedPlayerName && root.manualSelectedPlayerName === pName) ||
                                               (!root.manualSelectedPlayerName && isThisPlaying)
            readonly property bool isThisPlaying: pItem ? (pItem.status === "Playing" || pItem.isPlaying || pItem.playbackState === MprisPlaybackState.Playing) : false

            width: tabSourceList.width
            height: Style.space(42)
            radius: 8
            color: isSelected ? "#1db95420" : (rowMouse.containsMouse ? "#1e293b80" : "#111620")
            border.color: isSelected ? "#1db954" : (rowMouse.containsMouse ? "#334155" : "#1e293b")
            border.width: 1

            // Selection Mouse Area (covers whole left area)
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              anchors.rightMargin: Style.space(36)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (tabRow.pName) {
                  root.manualSelectedPlayerName = tabRow.pName
                  root.manualSelectedPlayerKey = tabRow.pName
                  if (root.mediaService) {
                    root.mediaService.selectPlayer(tabRow.pName)
                  }
                  root.refreshPosProc()
                }
              }
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: Style.space(8)

              Text {
                text: root.getSourceIcon(tabRow.pName)
                color: tabRow.isSelected ? "#1db954" : "#94a3b8"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(72)
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: tabRow.pTitle
                  color: tabRow.isSelected ? "#ffffff" : "#cbd5e1"
                  font.pixelSize: 11
                  font.bold: tabRow.isSelected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: tabRow.pArtist !== "" ? tabRow.pArtist : "Audio Source"
                  color: "#64748b"
                  font.pixelSize: 9
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              // Direct 1-Click Play/Pause on this Tab/Player
              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: 13
                color: tabRow.isThisPlaying ? "#1db954" : "#334155"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: tabRow.isThisPlaying ? "⏸" : "▶"
                  color: tabRow.isThisPlaying ? "#000000" : "#ffffff"
                  font.pixelSize: 9
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (tabRow.pName) {
                      playerctlProc.command = ["/home/chef_carthy/.local/bin/playerctl", "-p", tabRow.pName, "play-pause"]
                      playerctlProc.running = true
                      posPollTimer.restart()
                    }
                  }
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
