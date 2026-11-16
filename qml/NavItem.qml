import QtQuick

Item {
    id: r
    property string icon
    property string text
    property string trailing: ""
    property bool selected: false
    property string cover: ""
    property bool pinned: false
    property bool chevron: false
    property bool open: false
    signal clicked()
    signal rightClicked()

    height: 44
    scale: ma.pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: r.selected ? Theme.primaryContainer : Theme.fg
        opacity: r.selected ? 1 : (ma.containsMouse ? 0.08 : 0)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on opacity { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 14
        spacing: 14
        Item {
            width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.fill: parent; radius: 16; color: Theme.primary; opacity: r.selected && r.cover === "" ? 1 : 0; scale: r.selected ? 1 : 0.6; Behavior on opacity { NumberAnimation { duration: Theme.quick } } Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } } }
            Cover { visible: r.cover !== ""; anchors.fill: parent; radius: 9; source: r.cover }
            Text {
                visible: r.cover === ""
                anchors.centerIn: parent
                text: r.icon
                color: r.selected ? Theme.fgPrimary : Theme.fgVariant
                font.family: Theme.iconFont; renderType: Text.NativeRendering
                font.pixelSize: r.selected ? 20 : 24
                Behavior on font.pixelSize { NumberAnimation { duration: Theme.quick } }
            }
        }
        Text {
            visible: false
            text: r.icon
            color: r.selected ? Theme.fgPrimaryContainer : Theme.fgVariant
            font.family: Theme.iconFont; renderType: Text.NativeRendering
            font.pixelSize: 24
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: r.text
            color: r.selected ? Theme.fgPrimaryContainer : Theme.fg
            font.family: Theme.bodyFont
            font.pixelSize: 15
            font.weight: r.selected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            width: r.width - 14 - 32 - 14 - 20 - (trail.visible ? trail.width : 0) - (extra.visible ? 24 : 0)
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Text {
        id: trail
        visible: r.trailing !== ""
        text: r.trailing
        color: Theme.fgVariant
        font.family: Theme.bodyFont
        font.pixelSize: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        id: extra
        visible: r.pinned || r.chevron
        text: r.chevron ? "expand_more" : "push_pin"
        color: r.chevron ? Theme.fgVariant : Theme.primary
        font.family: Theme.iconFont; renderType: Text.NativeRendering
        font.pixelSize: r.chevron ? 22 : 16
        rotation: r.chevron && !r.open ? -90 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: m => m.button === Qt.RightButton ? r.rightClicked() : r.clicked() }
}
