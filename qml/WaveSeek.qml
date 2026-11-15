import QtQuick

// Wavy seek bar (Swiftify's wavy_progress.frag). The wave runs while playing and
// flattens when paused.
Item {
    id: r
    property real position: 0     // ms
    property real duration: 0     // ms
    property bool playing: false
    property color activeColor: Theme.primary
    property color trackColor: Theme.secondaryContainer
    property bool scrubbing: false
    property real scrubFraction: 0
    readonly property real fraction: duration > 0 ? Math.min(1, Math.max(0, (scrubbing ? scrubFraction * duration : position) / duration)) : 0
    readonly property bool expanded: hover.hovered || scrubbing
    signal seeked(real ms)

    implicitHeight: 26

    ShaderEffect {
        anchors.fill: parent
        property size itemSize: Qt.size(width, height)
        property real progress: r.fraction
        property real amplitude: r.playing ? 2.4 : 0
        Behavior on amplitude { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        property real wavelength: 34
        property real phase: 0
        Timer { running: r.playing && r.visible && Theme.motion; interval: 33; repeat: true; onTriggered: parent.phase -= 0.14 }
        property real thickness: r.expanded ? 6 : 4
        Behavior on thickness { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        property real handleWidth: r.expanded ? 4 : 0
        Behavior on handleWidth { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        property real handleHeight: 18
        property real gap: 4
        property color activeColor: r.activeColor
        property color trackColor: r.trackColor
        property color handleColor: r.activeColor
        fragmentShader: "qrc:/shaders/wavy_progress.frag.qsb"
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        anchors.fill: parent
        onPressed: m => { r.scrubbing = true; r.scrubFraction = Math.min(1, Math.max(0, m.x / width)) }
        onPositionChanged: m => { if (pressed) r.scrubFraction = Math.min(1, Math.max(0, m.x / width)) }
        onReleased: { r.scrubbing = false; r.seeked(r.scrubFraction * r.duration) }
    }
}
