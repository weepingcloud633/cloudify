import QtQuick

// A scalloped pill (Swiftify's wavy_pill.frag) with an icon. Scallops deepen on
// hover and run round the edge; the press scales it down a little.
Item {
    id: r
    property string icon: "play_arrow"
    property color fill: Theme.primary
    property color ink: Theme.fgPrimary
    property int iconSize: Math.round(height * 0.52)
    readonly property bool hovered: ma.containsMouse
    signal clicked()

    width: 52
    height: 52
    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property size itemSize: Qt.size(width, height)
        property color color: r.fill
        property real amplitude: ma.pressed ? 4 : (r.hovered ? 3.2 : 2.2)
        property real wavelength: 15
        property real phase: 0
        property real cornerRadius: Math.min(width, height) / 2
        Behavior on amplitude { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        Timer { running: r.hovered && r.visible && Theme.motion && Theme.windowActive; interval: 42; repeat: true; onTriggered: parent.phase += 0.15 }
        fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
    }
    Text {
        anchors.centerIn: parent
        text: r.icon
        color: r.ink
        font.family: Theme.iconFont; renderType: Text.NativeRendering
        font.pixelSize: r.iconSize
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.clicked() }
}
