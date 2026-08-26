import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import "MediaModel.js" as MediaModel

BarWidget {
  id: root
  moduleName: "custom.media"

  property var service: null

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
    if (!activePlayer) return "Spotify Flow"
    if (activePlayer.trackTitle) return String(activePlayer.trackTitle)
    if (activePlayer.metadata && activePlayer.metadata["xesam:title"]) return String(activePlayer.metadata["xesam:title"])
    return "Playing Audio"
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

  readonly property string album: {
    if (!activePlayer) return ""
    if (activePlayer.trackAlbum) return String(activePlayer.trackAlbum)
    if (activePlayer.metadata && activePlayer.metadata["xesam:album"]) return String(activePlayer.metadata["xesam:album"])
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

  property bool popupOpen: false
  function close() { popupOpen = false }

  // Animation phase for the 6-bar equalizer
  property real eqPhase: 0.0
  NumberAnimation on eqPhase {
    running: root.isPlaying && root.visible
    from: 0.0
    to: Math.PI * 2.0
    duration: 1200
    loops: Animation.Infinite
  }

  // -------------------------------------------------------------
  // TOP BAR CAPSULE (Single clean Spotify pill)
  // -------------------------------------------------------------
  visible: true
  implicitWidth: capsule.implicitWidth
  implicitHeight: barSize

  Rectangle {
    id: capsule
    anchors.verticalCenter: parent.verticalCenter
    height: Math.min(parent.height - Style.space(6), Style.space(30))
    implicitWidth: innerRow.implicitWidth + Style.space(16)
    radius: height / 2
    color: barMouse.containsMouse ? "#201db954" : (root.isPlaying ? "#141db954" : "#121417")
    border.color: root.isPlaying ? "#1db954" : (barMouse.containsMouse ? "#1db95488" : "#2a303c")
    border.width: 1

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 250 } }

    Row {
      id: innerRow
      anchors.centerIn: parent
      spacing: Style.space(8)

      // Spotify / Audio Badge Icon
      Rectangle {
        width: Style.space(18)
        height: Style.space(18)
        radius: width / 2
        color: root.isPlaying ? "#1db954" : "#2a2e39"
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: root.getSourceIcon(root.activePlayer ? root.activePlayer.identity : "")
          color: root.isPlaying ? "#000000" : "#8a94a6"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      // 6-Bar Equalizer
      Row {
        spacing: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.isPlaying

        Repeater {
          model: 6
          Rectangle {
            required property int index
            width: Style.space(3)
            height: Style.space(4) + Math.abs(Math.sin(root.eqPhase * 1.8 + index * 0.9)) * Style.space(10)
            radius: 1.5
            color: "#1db954"
            anchors.bottom: parent.bottom
          }
        }
      }

      // Title & Artist
      Row {
        spacing: Style.space(5)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: root.hasMedia ? root.title : "Spotify Flow"
          color: root.isPlaying ? "#ffffff" : "#94a3b8"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: root.isPlaying
          elide: Text.ElideRight
          maximumLineCount: 1
          width: Math.min(implicitWidth, 160)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.artist ? "· " + root.artist : ""
          color: "#1db954"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          visible: root.hasMedia && root.artist !== ""
          width: Math.min(implicitWidth, 100)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    MouseArea {
      id: barMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor

      onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
          root.popupOpen = !root.popupOpen
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

  // -------------------------------------------------------------
  // FLOATING SPOTIFY GLASS DECK
  // -------------------------------------------------------------
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight + Style.space(20))

    Column {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(12)

      // Header Row
      Row {
        width: parent.width

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
          width: Style.space(56)
          height: Style.space(20)
          radius: 10
          color: root.isPlaying ? "#1db95425" : "#2a303c40"
          border.color: root.isPlaying ? "#1db954" : "#475569"

          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "PLAYING" : "PAUSED"
            color: root.isPlaying ? "#1db954" : "#94a3b8"
            font.pixelSize: 9
            font.bold: true
          }
        }
      }

      // Hero Album Cover Art & Metadata
      Row {
        spacing: Style.space(14)
        width: parent.width

        Rectangle {
          width: Style.space(76)
          height: Style.space(76)
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
            text: "󰝚"
            color: "#1db954"
            font.pixelSize: 32
          }
        }

        Column {
          width: parent.width - Style.space(94)
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

          // Source Tag
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

        Row {
          width: parent.width
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

      // Playback Controls Deck (Previous, Large Play/Pause, Next)
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(16)

        Rectangle {
          width: Style.space(36)
          height: Style.space(36)
          radius: 18
          color: prevMouse.containsMouse ? "#2a303c" : "#1e2430"
          border.color: "#334155"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "󰒮"
            color: "#ffffff"
            font.pixelSize: 14
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
          width: Style.space(48)
          height: Style.space(48)
          radius: 24
          color: playMouse.containsMouse ? "#1ed760" : "#1db954"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "󰏤" : "󰐊"
            color: "#000000"
            font.pixelSize: 20
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
          width: Style.space(36)
          height: Style.space(36)
          radius: 18
          color: nextMouse.containsMouse ? "#2a303c" : "#1e2430"
          border.color: "#334155"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "󰒭"
            color: "#ffffff"
            font.pixelSize: 14
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

      // Tab Switcher (ONLY shown when there are 2 or more active tabs/players)
      Column {
        id: tabSourceList
        visible: root.sourcePlayers && root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(6)

        Rectangle {
          width: parent.width
          height: 1
          color: "#1e293b"
        }

        Text {
          text: "󱘖 OTHER ACTIVE TABS"
          color: "#94a3b8"
          font.pixelSize: 10
          font.bold: true
          font.letterSpacing: 1.0
        }

        Repeater {
          model: root.sourcePlayers && root.sourcePlayers.length > 1 ? root.sourcePlayers : []

          Rectangle {
            id: tabRow
            required property var modelData
            readonly property var pItem: modelData
            readonly property bool isSelected: root.activePlayer && pItem
              && MediaModel.playerKey(root.activePlayer) === MediaModel.playerKey(pItem)

            visible: !isSelected
            width: tabSourceList.width
            height: isSelected ? 0 : Style.space(34)
            radius: 8
            color: rowMouse.containsMouse ? "#1e293b80" : "#111620"
            border.color: rowMouse.containsMouse ? "#334155" : "transparent"
            border.width: 1

            Row {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: Style.space(8)
              visible: !tabRow.isSelected

              Text {
                text: root.getSourceIcon(tabRow.pItem ? tabRow.pItem.identity : "")
                color: "#1db954"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: tabRow.pItem ? (tabRow.pItem.trackTitle || tabRow.pItem.identity || "Other Tab") : "Other Tab"
                color: "#cbd5e1"
                font.pixelSize: 11
                elide: Text.ElideRight
                width: parent.width - Style.space(30)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

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
}
