import QtQuick

// Our own window bar: drag to move, double-click to maximize, three buttons.
Item {
    id: r
    required property var host
    property color ink: Theme.fgVariant
    height: 40

    // drag area behind the buttons
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: r.host.startSystemMove()
        onDoubleClicked: r.host.visibility === Window.Maximized ? r.host.showNormal() : r.host.showMaximized()
    }

    Row {
        x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 10
        Text { text: "cloud"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Cloudify"; color: r.ink; font.family: Theme.bodyFont; font.pixelSize: 13; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }

    Row {
        anchors.right: parent.right
        height: parent.height
        Repeater {
            model: [
                {i: "remove", a: "min"},
                {i: r.host.visibility === Window.Maximized ? "filter_none" : "crop_square", a: "max"},
                {i: "close", a: "close"}
            ]
            delegate: Item {
                required property var modelData
                width: 52; height: r.height
                Rectangle {
                    anchors.fill: parent
                    color: modelData.a === "close" ? "#e5484d" : Theme.fg
                    opacity: ma.pressed ? 0.28 : (ma.containsMouse ? (modelData.a === "close" ? 1 : 0.1) : 0)
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }
                Text {
                    anchors.centerIn: parent; text: modelData.i
                    font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: modelData.a === "max" ? 16 : 20
                    color: modelData.a === "close" && ma.containsMouse ? "white" : r.ink
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true
                    onClicked: modelData.a === "min" ? r.host.showMinimized()
                        : modelData.a === "max" ? (r.host.visibility === Window.Maximized ? r.host.showNormal() : r.host.showMaximized())
                        : r.host.close()
                }
            }
        }
    }
}
