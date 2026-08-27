import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "custom.voicetype"

  property string recordState: "idle" // "idle", "recording", "transcribing"
  property string currentText: ""
  property string currentMode: "autofix" // "autofix", "professional", "tech", "raw"
  property int recordDuration: 0
  property bool popupOpen: false
  property string copyStatusMsg: ""
  property string typeStatusMsg: ""

  function close() { popupOpen = false }

  // 1. Status Poller
  Timer {
    interval: root.recordState === "recording" ? 500 : 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!statusProc.running) statusProc.running = true
    }
  }

  // 2. Recording Duration Timer
  Timer {
    interval: 1000
    running: root.recordState === "recording"
    repeat: true
    onTriggered: root.recordDuration += 1
  }

  Process {
    id: statusProc
    command: ["/home/chef_carthy/.local/bin/omarchy-voice", "status"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(text.trim())
          if (res) {
            var oldState = root.recordState
            root.recordState = res.record_state || "idle"
            if (oldState !== "recording" && root.recordState === "recording") {
              root.recordDuration = 0
            }
            if (res.voice_data && res.voice_data.corrected_text) {
              if (root.currentText === "" || oldState === "transcribing" && root.recordState === "idle") {
                root.currentText = res.voice_data.corrected_text
                if (res.voice_data.mode) root.currentMode = res.voice_data.mode
              }
            }
          }
        } catch(e) {}
      }
    }
  }

  // 3. Action Processes
  Process {
    id: toggleProc
    command: ["/home/chef_carthy/.local/bin/omarchy-voice", "toggle"]
    running: false
    onExited: (code, status) => {
      statusProc.running = true
    }
  }

  Process {
    id: copyProc
    property string textToCopy: ""
    command: ["/home/chef_carthy/.local/bin/omarchy-voice", "copy", textToCopy]
    running: false
    onExited: (code, status) => {
      root.copyStatusMsg = "✓ Copied!"
      copyResetTimer.restart()
    }
  }

  Process {
    id: typeProc
    property string textToType: ""
    command: ["/home/chef_carthy/.local/bin/omarchy-voice", "type", textToType]
    running: false
    onExited: (code, status) => {
      root.typeStatusMsg = "✓ Typed!"
      typeResetTimer.restart()
      root.popupOpen = false
    }
  }

  Process {
    id: correctProc
    property string targetMode: "autofix"
    property string rawInput: ""
    command: ["/home/chef_carthy/.local/bin/omarchy-voice-correct", "--mode", targetMode, rawInput]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var trimmed = text.trim()
        if (trimmed) {
          root.currentText = trimmed
          root.currentMode = correctProc.targetMode
          saveStateProc.textToSave = trimmed
          saveStateProc.running = true
        }
      }
    }
  }

  Process {
    id: saveStateProc
    property string textToSave: ""
    command: ["/home/chef_carthy/.local/bin/omarchy-voice", "set-text", textToSave]
    running: false
  }

  Timer {
    id: copyResetTimer
    interval: 2500
    repeat: false
    onTriggered: root.copyStatusMsg = ""
  }

  Timer {
    id: typeResetTimer
    interval: 2500
    repeat: false
    onTriggered: root.typeStatusMsg = ""
  }

  function formatTime(secs) {
    var m = Math.floor(secs / 60)
    var s = secs % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  visible: true
  implicitWidth: barPill.implicitWidth
  implicitHeight: barSize

  // --- Top Bar Pill Widget ---
  Rectangle {
    id: barPill
    anchors.verticalCenter: parent.verticalCenter
    height: Math.min(parent.height - Style.space(4), Style.space(26))
    implicitWidth: pillRow.implicitWidth + Style.space(16)
    radius: Style.radius(4)
    color: {
      if (root.recordState === "recording") return Util.alpha(Color.urgent, 0.25)
      if (root.recordState === "transcribing") return Util.alpha(Color.accent, 0.25)
      if (pillMouse.containsMouse || root.popupOpen) return Util.alpha(Color.accent, 0.2)
      return Util.alpha(Color.background, 0.6)
    }
    border.color: {
      if (root.recordState === "recording") return Color.urgent
      if (root.recordState === "transcribing") return Color.accent
      if (pillMouse.containsMouse || root.popupOpen) return Color.accent
      return Util.alpha(Color.foreground, 0.18)
    }
    border.width: 1

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      // Mic / Recording Pulse Icon
      Text {
        text: root.recordState === "recording" ? "🔴" : (root.recordState === "transcribing" ? "⚡" : "🎙️")
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
        
        SequentialAnimation on opacity {
          running: root.recordState === "recording"
          loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
        }
      }

      Text {
        text: {
          if (root.recordState === "recording") return "Rec " + root.formatTime(root.recordDuration)
          if (root.recordState === "transcribing") return "Transcribing..."
          return "Voice"
        }
        color: root.recordState === "recording" ? Color.urgent : (root.recordState === "transcribing" ? Color.accent : Color.foreground)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
          toggleProc.running = true
        } else {
          root.popupOpen = !root.popupOpen
        }
      }
    }
  }

  // --- Voice Studio & Smart Corrector Popup Card ---
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(350))
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

          Text { text: "🎙️"; font.pixelSize: 13 }
          Text {
            text: "VOICE STUDIO & CORRECTOR"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.1
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Status Badge
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: statusBadgeRow.implicitWidth + Style.space(10)
          height: Style.space(16)
          radius: 8
          color: {
            if (root.recordState === "recording") return Util.alpha(Color.urgent, 0.2)
            if (root.recordState === "transcribing") return Util.alpha(Color.accent, 0.2)
            return Util.alpha(Color.foreground, 0.08)
          }
          border.color: {
            if (root.recordState === "recording") return Color.urgent
            if (root.recordState === "transcribing") return Color.accent
            return Util.alpha(Color.foreground, 0.15)
          }

          Row {
            id: statusBadgeRow
            anchors.centerIn: parent
            spacing: Style.space(3)
            Text {
              text: root.recordState === "recording" ? "●" : (root.recordState === "transcribing" ? "⚡" : "✓")
              color: root.recordState === "recording" ? Color.urgent : (root.recordState === "transcribing" ? Color.accent : Color.muted)
              font.pixelSize: 7
            }
            Text {
              text: root.recordState.toUpperCase()
              color: root.recordState === "recording" ? Color.urgent : (root.recordState === "transcribing" ? Color.accent : Color.muted)
              font.pixelSize: 7
              font.bold: true
            }
          }
        }
      }

      // Record Control Card
      Rectangle {
        width: parent.width
        height: Style.space(52)
        radius: 8
        color: Util.alpha(Color.background, 0.6)
        border.color: root.recordState === "recording" ? Color.urgent : Util.alpha(Color.foreground, 0.12)
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(12)

          // Big Record Button
          Rectangle {
            width: Style.space(36)
            height: Style.space(36)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.recordState === "recording" ? Color.urgent : (recBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.foreground, 0.1))
            border.color: root.recordState === "recording" ? "#ffffff" : Color.accent
            border.width: 2

            Text {
              anchors.centerIn: parent
              text: root.recordState === "recording" ? "⏹" : "🎙️"
              font.pixelSize: root.recordState === "recording" ? 14 : 16
              color: root.recordState === "recording" ? "#ffffff" : Color.foreground
            }

            MouseArea {
              id: recBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: toggleProc.running = true
            }
          }

          // Central Instructions / Waves
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - Style.space(56)

            Text {
              text: {
                if (root.recordState === "recording") return "Listening... (" + root.formatTime(root.recordDuration) + ")"
                if (root.recordState === "transcribing") return "Transcribing & Polishing with Whisper..."
                return "Click Mic to start voice dictation"
              }
              color: root.recordState === "recording" ? Color.urgent : (root.recordState === "transcribing" ? Color.accent : Color.foreground)
              font.pixelSize: 8
              font.bold: true
            }

            Text {
              text: root.recordState === "recording" ? "Speak clearly into your microphone..." : "Hotkey: Super+Ctrl+X or Right-Click bar icon"
              color: Color.muted
              font.pixelSize: 6
            }

            // Audio Wave Visualizer Bars when recording
            Row {
              visible: root.recordState === "recording"
              spacing: 3
              Repeater {
                model: 12
                Rectangle {
                  width: 3
                  height: 4 + Math.abs(Math.sin((index * 0.5) + (root.recordDuration * 2.0))) * 12
                  radius: 1.5
                  color: Color.urgent
                  anchors.bottom: parent.bottom
                }
              }
            }
          }
        }
      }

      // Transcribed & Corrected Text Area Card
      Rectangle {
        width: parent.width
        height: Style.space(110)
        radius: 8
        color: Util.alpha(Color.background, 0.8)
        border.color: textArea.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.15)
        border.width: 1

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.space(6)
          clip: true

          TextArea {
            id: textArea
            text: root.currentText
            placeholderText: "Transcribed speech will appear here. You can also edit this text freely..."
            placeholderTextColor: Color.muted
            color: Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 8
            wrapMode: Text.Wrap
            selectByMouse: true
            background: Item {}
            onTextChanged: {
              root.currentText = text
            }
          }
        }
      }

      // Tone / Mode Selector Row
      Row {
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: [
            { id: "autofix", label: "⚡ Auto-Fix", desc: "Clean Grammar & Typos" },
            { id: "professional", label: "💼 Formal", desc: "Professional Tone" },
            { id: "prompt", label: "💻 Tech/Code", desc: "Command/Prompt" },
            { id: "raw", label: "🧹 Raw", desc: "Verbatim" }
          ]

          Rectangle {
            width: (hudCol.width - Style.space(12)) / 4
            height: Style.space(18)
            radius: 4
            color: root.currentMode === modelData.id ? Util.alpha(Color.accent, 0.35) : (modeMouse.containsMouse ? Util.alpha(Color.foreground, 0.1) : Util.alpha(Color.foreground, 0.05))
            border.color: root.currentMode === modelData.id ? Color.accent : Util.alpha(Color.foreground, 0.1)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              color: root.currentMode === modelData.id ? Color.accent : Color.foreground
              font.pixelSize: 6
              font.bold: root.currentMode === modelData.id
            }

            MouseArea {
              id: modeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.currentText) {
                  correctProc.targetMode = modelData.id
                  correctProc.rawInput = root.currentText
                  correctProc.running = true
                } else {
                  root.currentMode = modelData.id
                }
              }
            }
          }
        }
      }

      // Action Buttons Toolbar Row
      Row {
        width: parent.width
        spacing: Style.space(6)

        // 1. Copy to Clipboard Button
        Rectangle {
          width: (hudCol.width - Style.space(12)) / 2
          height: Style.space(26)
          radius: 6
          color: copyMouse.containsMouse ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.background, 0.7)
          border.color: copyMouse.containsMouse || root.copyStatusMsg !== "" ? Color.accent : Util.alpha(Color.foreground, 0.2)
          border.width: 1

          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text {
              text: root.copyStatusMsg !== "" ? "✓" : "📋"
              font.pixelSize: 9
            }
            Text {
              text: root.copyStatusMsg !== "" ? root.copyStatusMsg : "Copy to Clipboard"
              color: root.copyStatusMsg !== "" ? Color.accent : Color.foreground
              font.pixelSize: 7
              font.bold: true
            }
          }

          MouseArea {
            id: copyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.currentText) {
                copyProc.textToCopy = root.currentText
                copyProc.running = true
              }
            }
          }
        }

        // 2. Type to Active Window Button
        Rectangle {
          width: (hudCol.width - Style.space(12)) / 2
          height: Style.space(26)
          radius: 6
          color: typeMouse.containsMouse ? Util.alpha("#10b981", 0.3) : Util.alpha(Color.background, 0.7)
          border.color: typeMouse.containsMouse || root.typeStatusMsg !== "" ? "#10b981" : Util.alpha(Color.foreground, 0.2)
          border.width: 1

          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text {
              text: root.typeStatusMsg !== "" ? "✓" : "⌨️"
              font.pixelSize: 9
            }
            Text {
              text: root.typeStatusMsg !== "" ? root.typeStatusMsg : "Type into Window"
              color: root.typeStatusMsg !== "" ? "#10b981" : Color.foreground
              font.pixelSize: 7
              font.bold: true
            }
          }

          MouseArea {
            id: typeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.currentText) {
                typeProc.textToType = root.currentText
                typeProc.running = true
              }
            }
          }
        }
      }

      // Secondary Utility Bar (Clear & Re-polish)
      Row {
        width: parent.width
        spacing: Style.space(6)

        // Re-polish Button
        Rectangle {
          width: (hudCol.width - Style.space(6)) / 2
          height: Style.space(18)
          radius: 4
          color: polishMouse.containsMouse ? Util.alpha(Color.foreground, 0.15) : Util.alpha(Color.foreground, 0.05)
          border.color: Util.alpha(Color.foreground, 0.1)

          Row {
            anchors.centerIn: parent
            spacing: 3
            Text { text: "🔄"; font.pixelSize: 7 }
            Text { text: "Re-Polish Grammar"; color: Color.muted; font.pixelSize: 6; font.bold: true }
          }

          MouseArea {
            id: polishMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.currentText) {
                correctProc.targetMode = root.currentMode
                correctProc.rawInput = root.currentText
                correctProc.running = true
              }
            }
          }
        }

        // Clear Button
        Rectangle {
          width: (hudCol.width - Style.space(6)) / 2
          height: Style.space(18)
          radius: 4
          color: clearMouse.containsMouse ? Util.alpha(Color.urgent, 0.2) : Util.alpha(Color.foreground, 0.05)
          border.color: Util.alpha(Color.foreground, 0.1)

          Row {
            anchors.centerIn: parent
            spacing: 3
            Text { text: "🗑️"; font.pixelSize: 7 }
            Text { text: "Clear Text"; color: Color.muted; font.pixelSize: 6; font.bold: true }
          }

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.currentText = ""
              saveStateProc.textToSave = ""
              saveStateProc.running = true
            }
          }
        }
      }
    }
  }
}
