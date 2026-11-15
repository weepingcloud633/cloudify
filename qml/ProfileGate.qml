import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// "Who's listening?": pick, add or remove a local profile; a PIN (optional) locks one.
Rectangle {
    id: r
    required property var app
    color: Theme.background

    property string mode: "pick"          // pick | pin | add | delete
    property var target: null
    property string error: ""
    property bool manage: false
    property string newColor: "#8fb8ff"
    readonly property var swatches: ["#8fb8ff", "#b69df8", "#f29fc8", "#f4a98a", "#e6c35c", "#7fd6a7"]

    function reset() { mode = "pick"; target = null; error = ""; pinField.text = "" }
    function choose(p) {
        if (manage) { target = p; mode = p.locked ? "pin" : "delete"; pinAction = p.locked ? "delete" : ""; error = ""; return }
        if (p.locked) { target = p; mode = "pin"; pinAction = "enter"; error = ""; pinField.text = ""; pinField.forceActiveFocus() }
        else r.app.enterProfile(p, "")
    }
    property string pinAction: "enter"
    function submitPin() {
        if (pinAction === "enter") {
            if (!r.app.enterProfile(target, pinField.text)) { error = "Wrong PIN"; pinField.text = "" }
        } else {
            var res = r.app.removeProfile(target, pinField.text)
            if (res !== "") { error = res; pinField.text = "" } else reset()
        }
    }

    MouseArea { anchors.fill: parent }   // swallow clicks

    Column {
        anchors.centerIn: parent
        spacing: 26
        width: Math.min(parent.width - 80, 760)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: r.mode === "add" ? "New profile" : r.mode === "pin" ? (r.pinAction === "delete" ? "PIN to remove " + r.target.name : "Enter PIN for " + r.target.name) : r.mode === "delete" ? "Remove " + (r.target ? r.target.name : "") + "?" : "Who's listening?"
            color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 36; font.weight: Font.Bold
        }

        // ---- pick ----
        Flow {
            visible: r.mode === "pick"
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, implicitWidth)
            spacing: 22
            Repeater {
                model: r.app.profiles
                delegate: Item {
                    id: pc
                    required property var modelData
                    width: 120; height: 160
                    scale: pma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                    Rectangle {
                        id: av
                        width: 112; height: 112; radius: 56; x: 4
                        color: pc.modelData.color
                        Text { anchors.centerIn: parent; text: pc.modelData.name.charAt(0).toUpperCase(); color: "#141414"; font.family: Theme.headFont; font.pixelSize: 46; font.weight: Font.Bold }
                        Rectangle { anchors.fill: parent; radius: 56; color: "white"; opacity: pma.containsMouse ? 0.12 : 0; Behavior on opacity { NumberAnimation { duration: Theme.quick } } }
                        Rectangle {
                            visible: pc.modelData.locked
                            width: 32; height: 32; radius: 16; x: parent.width - 30; y: parent.height - 30
                            color: Theme.containerHighest
                            Text { anchors.centerIn: parent; text: "lock"; color: Theme.fg; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 15 }
                        }
                        Rectangle {
                            visible: r.manage && r.app.profiles.length > 1
                            anchors.fill: parent; radius: 56; color: "#99000000"
                            Text { anchors.centerIn: parent; text: Theme.trash; color: Theme.error; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 34 }
                        }
                    }
                    Text { y: 122; width: parent.width; text: pc.modelData.name; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 16; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (!r.manage || r.app.profiles.length > 1) r.choose(pc.modelData) } }
                }
            }
            Item {
                width: 120; height: 160
                visible: !r.manage
                scale: ama.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                Rectangle { x: 4; width: 112; height: 112; radius: 56; color: "transparent"; border.width: 2; border.color: Theme.outline
                    Text { anchors.centerIn: parent; text: Theme.add; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 30 } }
                Text { y: 122; width: parent.width; text: "Add profile"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter }
                MouseArea { id: ama; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { r.mode = "add"; r.error = ""; nameField.text = ""; newPin.text = ""; nameField.forceActiveFocus() } }
            }
        }
        PillButton {
            visible: r.mode === "pick" && r.app.profiles.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            text: r.manage ? "Done" : "Manage profiles"
            variant: r.manage ? "filled" : "tonal"
            onClicked: r.manage = !r.manage
        }

        // ---- pin ----
        Column {
            visible: r.mode === "pin"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            TextField {
                id: pinField
                width: 240; height: 54
                echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 12
                horizontalAlignment: TextInput.AlignHCenter
                color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 24
                placeholderText: "PIN"; placeholderTextColor: Theme.fgVariant
                background: Rectangle { radius: 27; color: Theme.container; border.width: pinField.activeFocus ? 2 : 0; border.color: Theme.primary }
                onAccepted: r.submitPin()
            }
            Text { visible: r.error !== ""; anchors.horizontalCenter: parent.horizontalCenter; text: r.error; color: Theme.error; font.family: Theme.bodyFont; font.pixelSize: 14 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                PillButton { text: "Back"; variant: "text"; onClicked: r.reset() }
                PillButton { text: r.pinAction === "delete" ? "Remove" : "Unlock"; variant: "filled"; onClicked: r.submitPin() }
            }
        }

        // ---- delete (no PIN) ----
        Row {
            visible: r.mode === "delete"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Text { text: "Its playlists and likes are deleted too."; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
            PillButton { text: "Cancel"; variant: "text"; onClicked: r.reset() }
            PillButton { text: "Remove"; variant: "filled"; onClicked: { r.pinAction = "delete"; pinField.text = ""; r.submitPin() } }
        }

        // ---- add ----
        Column {
            visible: r.mode === "add"
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            width: 340
            TextField {
                id: nameField
                width: parent.width; height: 50
                placeholderText: "Name"; placeholderTextColor: Theme.fgVariant; color: Theme.fg
                font.family: Theme.bodyFont; font.pixelSize: 17; leftPadding: 20; maximumLength: 24
                background: Rectangle { radius: 25; color: Theme.container; border.width: nameField.activeFocus ? 2 : 0; border.color: Theme.primary }
            }
            Row {
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: r.swatches
                    delegate: Rectangle {
                        required property string modelData
                        width: 36; height: 36; radius: 18; color: modelData
                        border.width: r.newColor === modelData ? 3 : 0; border.color: Theme.fg
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.newColor = parent.modelData }
                    }
                }
            }
            TextField {
                id: newPin
                width: parent.width; height: 50
                echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 12
                placeholderText: "PIN (optional, 4+ digits)"; placeholderTextColor: Theme.fgVariant; color: Theme.fg
                font.family: Theme.bodyFont; font.pixelSize: 17; leftPadding: 20
                background: Rectangle { radius: 25; color: Theme.container; border.width: newPin.activeFocus ? 2 : 0; border.color: Theme.primary }
                onAccepted: mk.clicked()
            }
            Text { visible: r.error !== ""; text: r.error; color: Theme.error; font.family: Theme.bodyFont; font.pixelSize: 14 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                PillButton { text: "Cancel"; variant: "text"; onClicked: r.reset() }
                PillButton {
                    id: mk; text: "Create"; variant: "filled"
                    onClicked: { var e = r.app.addProfile(nameField.text, r.newColor, newPin.text); if (e !== "") r.error = e; else r.reset() }
                }
            }
        }
    }
}
