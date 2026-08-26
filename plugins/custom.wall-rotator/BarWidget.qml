import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: 32
    implicitHeight: 28

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        color: mouseArea.containsMouse ? "#20ffffff" : "transparent"
        border.color: mouseArea.containsMouse ? "#40ffffff" : "transparent"

        Text {
            anchors.centerIn: parent
            text: "🎨"
            font.pixelSize: 14
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    // Left-click: Cycle next wallpaper
                    omarchyProcess.start("/home/chef_carthy/.local/bin/omarchy-walltheme", ["auto", "next"])
                } else if (mouse.button === Qt.RightButton) {
                    // Right-click: Open background switcher
                    omarchyProcess.start("omarchy", ["theme", "bg-switcher"])
                }
            }
        }
    }
}
