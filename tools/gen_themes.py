import re, json
src = open(r'D:\Drizzle\_ref_swiftify\src\theme\Themes.cpp', encoding='utf-8').read()
latte = re.search(r'kLatte \{(.*?)\};', src, re.S).group(1)
def hexes(s): return ['#' + h for h in re.findall(r'0xff([0-9a-fA-F]{6})', s)]
latte = hexes(latte)
body = src[src.index('const QList<Family> kFamilies'):src.index('qreal linear')]
out = []
for m in re.finditer(r'\{QStringLiteral\("([^"]+)"\), QStringLiteral\("([^"]+)"\),\s*(kLatte|\{[^}]*\}),\s*\{([^}]*)\}\}', body, re.S):
    fid, name, light, dark = m.groups()
    light = latte if light == 'kLatte' else hexes(light)
    dark = hexes(dark)
    assert len(light) == 13 and len(dark) == 13, (fid, len(light), len(dark))
    out.append({'id': fid, 'name': name, 'light': light, 'dark': dark})
head = ('pragma Singleton\nimport QtQuick\n'
        '// Colour themes from Swiftify (GPL-3.0, (C) shred0s). Each variant: background, surface low, surface,\n'
        '// container, container high, container highest, text, subtext, outline, primary, secondary, tertiary, error.\n'
        'QtObject {\n    readonly property var families: ')
open(r'D:\Drizzle\cloud-music\qml\Themes.qml', 'w', encoding='utf-8').write(head + json.dumps(out) + '\n}\n')
print(len(out), 'themes')
