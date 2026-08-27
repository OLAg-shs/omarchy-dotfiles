import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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

  // -------------------------------------------------------------
  // STORAGE & CLEANER TELEMETRY
  // -------------------------------------------------------------
  property string diskTotalStr: "475 GB"
  property string diskUsedStr: "47 GB"
  property string diskFreeStr: "428 GB"
  property real diskPercent: 10.0
  property real userCleanableBytes: 0
  property string userCleanableStr: "0 B"
  property string systemCleanableStr: "0 B"
  property string cleanableStr: "0 B"
  property bool isCleaning: false
  property string cleanStatusMsg: ""

  Process {
    id: storageScanProc
    command: ["/home/chef_carthy/.local/bin/omarchy-storage-cleaner", "scan"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(text.trim())
          if (res && res.disk) {
            root.diskTotalStr = res.disk.total_str || "475 GB"
            root.diskUsedStr = res.disk.used_str || "47 GB"
            root.diskFreeStr = res.disk.free_str || "428 GB"
            root.diskPercent = res.disk.percent || 10.0
            root.userCleanableBytes = res.user_cleanable_bytes || 0
            root.userCleanableStr = res.user_cleanable_str || "0 B"
            root.systemCleanableStr = res.system_cleanable_str || "0 B"
            root.cleanableStr = res.total_cleanable_str || "0 B"
          }
        } catch(e) {}
      }
    }
  }

  Process {
    id: storageCleanProc
    command: ["/home/chef_carthy/.local/bin/omarchy-storage-cleaner", "clean", "safe"]
    running: false
    onExited: (exitCode, exitStatus) => {
      root.isCleaning = false
      root.cleanStatusMsg = "✓ Cleaned!"
      cleanResetTimer.restart()
      storageScanProc.running = true
    }
  }

  Timer {
    id: cleanResetTimer
    interval: 3000
    repeat: false
    onTriggered: root.cleanStatusMsg = ""
  }

  Timer {
    id: storageScanTimer
    interval: 30000
    running: root.popupOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!storageScanProc.running) storageScanProc.running = true
    }
  }

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
      root.pinned = !root.pinned
      root.popupOpen = root.pinned
    }

    function togglePin(): void {
      root.pinned = !root.pinned
      root.popupOpen = root.pinned
    }

    function setPinned(val: string): void {
      root.pinned = (val === "true" || val === "1")
      root.popupOpen = root.pinned
    }

    function open(): void {
      root.pinned = true
      root.popupOpen = true
    }

    function close(): void {
      root.pinned = false
      root.popupOpen = false
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
  // DROPDOWN PANEL & PIN STATE
  // -------------------------------------------------------------
  property bool pinned: false
  property bool popupOpen: false

  function close() {
    pinned = false
    popupOpen = false
  }

  // -------------------------------------------------------------
  // DELAYED AUTO-CLOSE TIMER (3.5s Grace Period)
  // -------------------------------------------------------------
  Timer {
    id: autoCloseTimer
    interval: 3500
    repeat: false
    onTriggered: {
      if (!root.pinned && !arrowHover.hovered && !panelHover.hovered) {
        root.popupOpen = false
      }
    }
  }

  // -------------------------------------------------------------
  // TOP BAR TRIGGER: Single Downward Chevron Arrow (beside battery)
  // -------------------------------------------------------------
  visible: true
  implicitWidth: triggerArrow.implicitWidth
  implicitHeight: root.barSize

  Item {
    id: triggerArrow
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: Style.space(22)
    implicitHeight: root.barSize

    Rectangle {
      id: arrowBg
      anchors.centerIn: parent
      width: Style.space(22)
      height: Style.space(22)
      radius: width / 2
      color: (arrowMouse.containsMouse || root.popupOpen) ? Util.alpha(Color.accent, 0.18) : "transparent"
      border.color: (arrowMouse.containsMouse || root.popupOpen) ? Color.accent : "transparent"
      border.width: 1

      Behavior on color { ColorAnimation { duration: 150 } }
      Behavior on border.color { ColorAnimation { duration: 150 } }

      Text {
        anchors.centerIn: parent
        text: root.popupOpen ? "󰅃" : "󰅀"
        color: (arrowMouse.containsMouse || root.popupOpen) ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 13
        font.bold: true
      }
    }

    HoverHandler {
      id: arrowHover
      onHoveredChanged: {
        if (hovered) {
          autoCloseTimer.stop()
          root.popupOpen = true
        } else if (!root.pinned) {
          autoCloseTimer.restart()
        }
      }
    }

    MouseArea {
      id: arrowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.pinned = !root.pinned
        if (root.pinned) {
          autoCloseTimer.stop()
          root.popupOpen = true
        } else {
          autoCloseTimer.restart()
        }
      }
    }
  }

  // -------------------------------------------------------------
  // POPUP: CUSTOM SLIM (78px) & LONG FLOATING STRIP (16px Radius)
  // -------------------------------------------------------------
  PopupWindow {
    id: popup
    anchor {
      window: triggerArrow.QsWindow.window
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        if (!root.bar) return
        var target = triggerArrow
        var popupWidth = popup.implicitWidth
        var popupHeight = popup.implicitHeight
        var localX = target.width / 2 - popupWidth / 2
        var localY = target.height + Style.gapsOut
        var window = target.QsWindow.window
        if (!window) return
        var point = window.contentItem.mapFromItem(target, localX, localY)
        point.x = Math.max(Style.gapsOut, Math.min(point.x, window.width - popupWidth - Style.gapsOut))
        popup.anchor.rect.x = Math.round(point.x)
        popup.anchor.rect.y = Math.round(point.y)
      }
    }

    visible: root.popupOpen || cardSurface.opacity > 0
    color: "transparent"
    implicitWidth: Style.space(78)
    implicitHeight: panelDeck.implicitHeight + Style.space(32)

    // Outside-click dismissal via Hyprland focus grab when pinned
    HyprlandFocusGrab {
      active: root.popupOpen && root.pinned
      windows: triggerArrow.QsWindow.window ? [popup, triggerArrow.QsWindow.window] : [popup]
      onCleared: root.close()
    }

    Item {
      anchors.fill: parent
      anchors.margins: Style.space(3)

      // Drop Shadow Layer (Multi-tiered soft elevation glow)
      Rectangle {
        anchors.fill: cardSurface
        anchors.topMargin: 4
        anchors.bottomMargin: -4
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: 18
        color: "#00000066"
        opacity: cardSurface.opacity
      }
      Rectangle {
        anchors.fill: cardSurface
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: 17
        color: "#00000040"
        opacity: cardSurface.opacity
      }

      // Main Card Surface: 78px Slim Long Strip with 16px Rounded Corners & Accent Border
      Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: 16
        color: Color.popups.background
        border.color: Util.alpha(Color.accent, 0.45)
        border.width: 1.5
        clip: true
        opacity: root.popupOpen ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Inner subtle ambient top highlight
        Rectangle {
          anchors.fill: parent
          radius: 16
          gradient: Gradient {
            GradientStop { position: 0.0; color: Util.alpha(Color.accent, 0.09) }
            GradientStop { position: 0.25; color: "transparent" }
            GradientStop { position: 1.0; color: Util.alpha("#000000", 0.28) }
          }
        }

        HoverHandler {
          id: panelHover
          onHoveredChanged: {
            if (hovered) {
              autoCloseTimer.stop()
              root.popupOpen = true
            } else if (!root.pinned) {
              autoCloseTimer.restart()
            }
          }
        }

        // ---------------------------------------------------------
        // VERTICAL STRIP DECK (AMPLIFIED VERTICAL SPACING)
        // ---------------------------------------------------------
        Column {
          id: panelDeck
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(16)

          // =======================================================
          // SECTION 1: CHEF PLAYER
          // =======================================================
          Column {
            width: parent.width
            spacing: Style.space(8)

            // Header Icon & Pin Badge
            Item {
              width: parent.width
              height: Style.space(16)

              Text {
                text: ""
                color: Color.accent
                font.pixelSize: 12
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Rectangle {
                width: Style.space(16)
                height: Style.space(16)
                radius: 8
                color: root.pinned ? Util.alpha(Color.accent, 0.25) : "transparent"
                border.color: root.pinned ? Color.accent : Util.alpha(Color.muted, 0.3)
                border.width: 1
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "󰐃"
                  color: root.pinned ? Color.accent : Color.muted
                  font.pixelSize: 9
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.pinned = !root.pinned
                    if (root.pinned) {
                      autoCloseTimer.stop()
                      root.popupOpen = true
                    } else {
                      autoCloseTimer.restart()
                    }
                  }
                }
              }
            }

            // Album Art
            Rectangle {
              width: Style.space(56)
              height: Style.space(56)
              radius: 10
              color: Util.alpha(Color.background, 0.8)
              border.color: Util.alpha(Color.foreground, 0.15)
              border.width: 1
              anchors.horizontalCenter: parent.horizontalCenter

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
                color: Color.accent
                font.pixelSize: 22
              }
            }

            // Title & Artist
            Column {
              width: parent.width
              spacing: 2

              Text {
                text: root.hasMedia ? root.title : "No Media"
                color: Color.foreground
                font.pixelSize: 9
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.hasMedia && root.artist ? root.artist : "Paused"
                color: Color.muted
                font.pixelSize: 8
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                width: parent.width
              }
            }

            // 1.3 REAL DRAG-TO-SEEK SLIDER (Dynamic Theme Matched)
            Column {
              width: parent.width
              spacing: 2
              visible: root.hasMedia

              Slider {
                id: seekSlider
                width: parent.width
                height: Style.space(16)
                from: 0
                to: Math.max(1.0, root.lengthSec)
                value: (pressed || visualDrag) ? dragVal : root.positionSec
                stepSize: 1.0

                property bool visualDrag: false
                property real dragVal: 0.0

                background: Rectangle {
                  x: seekSlider.leftPadding
                  y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                  implicitWidth: 50
                  implicitHeight: 4
                  width: seekSlider.availableWidth
                  height: implicitHeight
                  radius: 2
                  color: Util.alpha(Color.foreground, 0.18)

                  Rectangle {
                    width: seekSlider.visualPosition * parent.width
                    height: parent.height
                    color: Color.accent
                    radius: 2
                  }
                }

                handle: Rectangle {
                  x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                  y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                  implicitWidth: 10
                  implicitHeight: 10
                  radius: 5
                  color: seekSlider.pressed ? "#ffffff" : Color.accent
                  border.color: Util.alpha(Color.background, 0.6)
                  border.width: 1
                  scale: (seekSlider.hovered || seekSlider.pressed) ? 1.25 : 1.0

                  Behavior on scale { NumberAnimation { duration: 100 } }
                }

                onPressedChanged: {
                  if (pressed) {
                    visualDrag = true
                    dragVal = value
                  } else {
                    visualDrag = false
                    root.seekTo(value)
                  }
                }

                onMoved: {
                  dragVal = value
                  root.seekTo(value)
                }
              }

              // Live Timestamps
              Item {
                width: parent.width
                height: Style.space(10)

                Text {
                  text: root.formatTime(seekSlider.pressed ? seekSlider.value : root.positionSec)
                  color: Color.muted
                  font.pixelSize: 7
                  anchors.left: parent.left
                }
                Text {
                  text: root.formatTime(root.lengthSec)
                  color: Color.muted
                  font.pixelSize: 7
                  anchors.right: parent.right
                }
              }
            }

            // 1.4 Cohesive Playback Controls
            Row {
              spacing: Style.space(4)
              anchors.horizontalCenter: parent.horizontalCenter
              visible: root.hasMedia

              Rectangle {
                width: Style.space(18)
                height: Style.space(18)
                radius: 9
                color: prevMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "⏮"
                  color: prevMouse.containsMouse ? Color.accent : Color.foreground
                  font.pixelSize: 9
                }
                MouseArea {
                  id: prevMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.skipPrev()
                }
              }

              Rectangle {
                width: Style.space(24)
                height: Style.space(24)
                radius: 12
                color: playMouse.containsMouse ? Color.foreground : Color.accent
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: root.isPlaying ? "⏸" : "▶"
                  color: Color.background
                  font.pixelSize: 10
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

              Rectangle {
                width: Style.space(18)
                height: Style.space(18)
                radius: 9
                color: nextMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "⏭"
                  color: nextMouse.containsMouse ? Color.accent : Color.foreground
                  font.pixelSize: 9
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

            // 1.5 Mini Active Player Source Badge
            Rectangle {
              width: parent.width
              height: Style.space(18)
              radius: 9
              color: Util.alpha(Color.background, 0.6)
              border.color: Util.alpha(Color.foreground, 0.15)
              border.width: 1
              visible: root.hasMedia

              Row {
                anchors.centerIn: parent
                spacing: 3
                Text {
                  text: root.getSourceIcon(root.manualSelectedPlayerName || (root.activePlayer ? root.activePlayer.identity : ""))
                  color: Color.accent
                  font.pixelSize: 8
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: (root.manualSelectedPlayerName || (root.activePlayer ? (root.activePlayer.identity || "Media") : "Audio")).substring(0, 8)
                  color: Color.muted
                  font.pixelSize: 7
                  elide: Text.ElideRight
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }

          // =======================================================
          // DIVIDER 1
          // =======================================================
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.foreground, 0.12)
          }

          // =======================================================
          // SECTION 2: SYSTEM THEME SWITCHER (VERTICAL STACK)
          // =======================================================
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "🎨 THEME"
              color: Color.accent
              font.pixelSize: 8
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }

            // Next Theme Button
            Rectangle {
              width: parent.width
              height: Style.space(24)
              radius: 6
              color: nextThemeMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.background, 0.6)
              border.color: nextThemeMouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.15)
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 3
                Text { text: "🎲"; font.pixelSize: 8 }
                Text { text: "Next"; color: Color.foreground; font.pixelSize: 8; font.bold: true }
              }
              MouseArea {
                id: nextThemeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  wallProc.command = ["/home/chef_carthy/.local/bin/omarchy-theme-cycle"]
                  wallProc.running = true
                }
              }
            }

            // Wallpaper Switcher Button
            Rectangle {
              width: parent.width
              height: Style.space(24)
              radius: 6
              color: bgThemeMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.background, 0.6)
              border.color: bgThemeMouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.15)
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 3
                Text { text: "🖼"; font.pixelSize: 8 }
                Text { text: "Wall"; color: Color.foreground; font.pixelSize: 8; font.bold: true }
              }
              MouseArea {
                id: bgThemeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  wallProc.command = ["omarchy", "theme", "bg-switcher"]
                  wallProc.running = true
                }
              }
            }

            // Full Visual Picker Button
            Rectangle {
              width: parent.width
              height: Style.space(24)
              radius: 6
              color: pickerThemeMouse.containsMouse ? Util.alpha(Color.accent, 0.2) : Util.alpha(Color.background, 0.6)
              border.color: pickerThemeMouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.15)
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 3
                Text { text: "📂"; font.pixelSize: 8 }
                Text { text: "Pick"; color: Color.foreground; font.pixelSize: 8; font.bold: true }
              }
              MouseArea {
                id: pickerThemeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  wallProc.command = ["/usr/share/omarchy/bin/omarchy-theme-switcher"]
                  wallProc.running = true
                }
              }
            }
          }

          // =======================================================
          // DIVIDER 2
          // =======================================================
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.foreground, 0.12)
          }

          // =======================================================
          // SECTION 3: HARDWARE TELEMETRY (VERTICAL TILES)
          // =======================================================
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "⚡ STATS"
              color: Color.accent
              font.pixelSize: 8
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }

            // Temp Card
            Rectangle {
              width: parent.width
              height: Style.space(28)
              radius: 6
              color: Util.alpha(Color.background, 0.6)
              border.color: Util.alpha(Color.foreground, 0.12)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "PEAK TEMP"; color: Color.muted; font.pixelSize: 6; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.tempPeak + "°C"; color: root.tempColor; font.pixelSize: 9; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }

            // CPU Load Card
            Rectangle {
              width: parent.width
              height: Style.space(28)
              radius: 6
              color: Util.alpha(Color.background, 0.6)
              border.color: Util.alpha(Color.foreground, 0.12)

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "CPU LOAD"; color: Color.muted; font.pixelSize: 6; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.cpuLoad; color: root.cpuLoad > 3.0 ? Color.urgent : Color.accent; font.pixelSize: 9; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }

            // RAM Utilization Bar
            Column {
              width: parent.width
              spacing: 2

              Text {
                text: "RAM " + root.ramPercent + "%"
                color: Color.muted
                font.pixelSize: 7
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Util.alpha(Color.foreground, 0.15)

                Rectangle {
                  width: parent.width * Math.min(1.0, root.ramPercent / 100.0)
                  height: parent.height
                  radius: 2
                  color: root.ramPercent > 85 ? Color.urgent : (root.ramPercent > 70 ? "#f59e0b" : Color.accent)
                }
              }
            }
          }

          // =======================================================
          // DIVIDER 3
          // =======================================================
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.foreground, 0.12)
          }

          // =======================================================
          // SECTION 4: SMART STORAGE & CLEANER
          // =======================================================
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "🧹 STORAGE"
              color: Color.accent
              font.pixelSize: 8
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }

            // Disk Usage Card
            Rectangle {
              width: parent.width
              height: Style.space(30)
              radius: 6
              color: Util.alpha(Color.background, 0.6)
              border.color: Util.alpha(Color.foreground, 0.12)

              Column {
                anchors.centerIn: parent
                spacing: 2
                width: parent.width - Style.space(8)

                Item {
                  width: parent.width
                  height: Style.space(8)
                  Text { text: "DISK"; color: Color.muted; font.pixelSize: 6; font.bold: true; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                  Text { text: Math.round(root.diskPercent) + "% (" + root.diskFreeStr + ")"; color: Color.foreground; font.pixelSize: 6; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                }

                Rectangle {
                  width: parent.width
                  height: 4
                  radius: 2
                  color: Util.alpha(Color.foreground, 0.15)

                  Rectangle {
                    width: parent.width * Math.min(1.0, root.diskPercent / 100.0)
                    height: parent.height
                    radius: 2
                    color: root.diskPercent > 85 ? Color.urgent : Color.accent
                  }
                }
              }
            }

            // Quick Clean Action Button
            Rectangle {
              width: parent.width
              height: Style.space(24)
              radius: 6
              color: cleanBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : (root.isCleaning ? Util.alpha(Color.accent, 0.35) : Util.alpha(Color.background, 0.6))
              border.color: cleanBtnMouse.containsMouse || root.isCleaning ? Color.accent : Util.alpha(Color.foreground, 0.15)
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 3
                Text {
                  text: root.isCleaning ? "⏳" : (root.cleanStatusMsg !== "" || root.userCleanableBytes < 10 * 1024 * 1024 ? "✓" : "🧹")
                  font.pixelSize: 8
                }
                Text {
                  text: {
                    if (root.cleanStatusMsg !== "") return root.cleanStatusMsg
                    if (root.isCleaning) return "Cleaning..."
                    if (root.userCleanableBytes > 10 * 1024 * 1024) return "Free " + root.userCleanableStr
                    return "✓ Caches Clean"
                  }
                  color: root.userCleanableBytes > 10 * 1024 * 1024 ? Color.foreground : Color.muted
                  font.pixelSize: 7
                  font.bold: true
                }
              }

              MouseArea {
                id: cleanBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!root.isCleaning) {
                    root.isCleaning = true
                    storageCleanProc.running = true
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
