def rd(p): return open(p, encoding='utf-8').read()
def wr(p, t): open(p, 'w', encoding='utf-8').write(t)
def sub(t, old, new, label=''):
    if old not in t: print('MISSING', label or old[:70].replace('\n', ' ')); return t
    return t.replace(old, new, 1)
m = rd(r'qml\Main.qml')
m = sub(m, '    function applySettings() {\n        applyFx()', '''    readonly property string langArg: { var a = Qt.application.arguments; for (var i = 0; i < a.length; i++) if (a[i].indexOf("--lang=") === 0) return a[i].substring(7); return "" }
    function applySettings() {
        Tr.set(langArg !== "" ? langArg : settings.language)
        applyFx()''')
wr(r'qml\Main.qml', m)
s = rd(r'qml\SettingsView.qml')
s = sub(s, '    property var devices: []\n', '''    property var devices: []
    Popup {
        id: langMenu
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10; width: 320
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: Tr.t("Language"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; topPadding: 4; bottomPadding: 8 }
            NavItem { width: 300; icon: "translate"; text: Tr.t("Automatic"); selected: r.app.settings.language === "auto"; onClicked: { r.app.setSetting("language", "auto"); langMenu.close() } }
            Repeater {
                model: Tr.names
                delegate: NavItem {
                    required property var modelData
                    width: 300; icon: "translate"; text: modelData.name; selected: r.app.settings.language === modelData.code
                    onClicked: { r.app.setSetting("language", modelData.code); langMenu.close() }
                }
            }
        }
    }
''')
wr(r'qml\SettingsView.qml', s)
