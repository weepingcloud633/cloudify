import QtQuick

// variant: "filled" | "tonal" | "text"
Item {
    id: r
    property string text
    property string icon
    property string variant: "tonal"
    property bool enabled: true
    signal clicked()

    implicitWidth: row.implicitWidth + 36
    implicitHeight: 40
    opacity: enabled ? 1 : 0.4
    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }

    readonly property color bg: variant === "filled" ? Theme.primary : (variant === "tonal" ? Theme.secondaryContainer : "transparent")
    readonly property color fg: variant === "filled" ? Theme.fgPrimary : (variant === "tonal" ? Theme.fgSecondaryContainer : Theme.primary)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: r.bg
        Rectangle { anchors.fill: parent; radius: parent.radius; color: r.fg; opacity: ma.pressed ? 0.16 : (ma.containsMouse ? 0.08 : 0) }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text { visible: r.icon !== ""; text: r.icon; color: r.fg; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
        Text { text: r.text; color: r.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: r.enabled; cursorShape: Qt.PointingHandCursor; onClicked: r.clicked() }
}
