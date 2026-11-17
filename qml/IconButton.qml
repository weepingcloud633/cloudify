import QtQuick

Item {
    id: r
    property string icon
    property bool active: false
    property color ink: active ? Theme.primary : Theme.fgVariant
    property int size: 40
    property int iconSize: 24
    property string fontFamily: Theme.iconFont
    // the clickable (and hover) disc hugs the icon, so a click beside a button does not trigger it
    readonly property int hit: Math.min(size, iconSize + 10)
    signal clicked()

    width: size
    height: size
    scale: ma.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }

    Rectangle {
        anchors.centerIn: parent
        width: r.hit; height: r.hit
        radius: width / 2
        color: Theme.fg
        opacity: ma.pressed ? 0.14 : (ma.containsMouse ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
    }
    Text {
        anchors.centerIn: parent
        text: r.icon
        color: r.ink
        font.family: r.fontFamily; renderType: Text.NativeRendering
        font.pixelSize: r.iconSize
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }
    MouseArea { id: ma; anchors.centerIn: parent; width: r.hit; height: r.hit; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.clicked() }
}
