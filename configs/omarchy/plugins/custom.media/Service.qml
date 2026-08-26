import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "MediaModel.js" as MediaModel

QtObject {
  id: service

  readonly property var activePlayer: {
    var raw = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < raw.length; i++) {
      var p = raw[i]
      if (p && p.playbackState === MprisPlaybackState.Playing) return p
    }
    for (var j = 0; j < raw.length; j++) {
      var p2 = raw[j]
      if (p2 && MediaModel.hasMetadata(p2)) return p2
    }
    return null
  }

  readonly property var sourcePlayers: {
    var list = []
    var seen = {}
    var raw = Mpris.players ? Mpris.players.values : []
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

  readonly property string artUrl: activePlayer ? MediaModel.extractArtUrl(activePlayer) : ""

  function runAction(action, isGlobal, targetKey) {
    var target = null
    var raw = Mpris.players ? Mpris.players.values : []
    if (targetKey) {
      for (var i = 0; i < raw.length; i++) {
        if (MediaModel.playerKey(raw[i]) === targetKey) {
          target = raw[i]
          break
        }
      }
    }
    if (!target) target = activePlayer

    if (!target) return

    if (action === "playPause") {
      if (typeof target.togglePlaying === "function") target.togglePlaying()
      else if (target.playbackState === MprisPlaybackState.Playing) target.pause()
      else target.play()
    } else if (action === "previous") {
      if (typeof target.previous === "function") target.previous()
    } else if (action === "next") {
      if (typeof target.next === "function") target.next()
    } else if (action === "play") {
      if (typeof target.play === "function") target.play()
    } else if (action === "pause") {
      if (typeof target.pause === "function") target.pause()
    }
  }

  function selectPlayer(key) {
    var raw = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < raw.length; i++) {
      if (MediaModel.playerKey(raw[i]) === key) {
        if (typeof raw[i].play === "function") raw[i].play()
        break
      }
    }
  }
}
