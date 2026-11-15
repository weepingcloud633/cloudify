import QtQuick

// A still wavy divider, drawn with the same shader as the seek bar.
ShaderEffect {
    property color tint: Theme.outlineVariant
    height: 10
    property size itemSize: Qt.size(width, height)
    property real progress: 1
    property real amplitude: 1.8
    property real wavelength: 22
    property real phase: 0
    property real thickness: 2
    property real handleWidth: 0
    property real handleHeight: 0
    property real gap: 0
    property color activeColor: tint
    property color trackColor: tint
    property color handleColor: tint
    fragmentShader: "qrc:/shaders/wavy_progress.frag.qsb"
}
