"""List the user-visible English strings in the QML files (for translations)."""
import glob
import re
import sys

KEYS = r'(?:text|title|hint|heading|placeholderText|label|t|n)'
PAT = re.compile(r'\b' + KEYS + r':\s*"([^"\\\n]{2,90})"')
SKIP_FILES = ('Themes.qml', 'ProfileGate.qml')


def collect():
    found = {}
    for f in sorted(glob.glob('qml/*.qml')):
        if f.endswith(SKIP_FILES):
            continue
        t = open(f, encoding='utf-8').read()
        for m in PAT.finditer(t):
            s = m.group(1)
            if not re.search(r'[A-Za-z]{2}', s):
                continue
            if re.fullmatch(r'[a-z_0-9]+', s):  # icon names and ids
                continue
            if s.startswith(('qrc:', 'http', '#', 'file:')):
                continue
            found.setdefault(s, []).append(f)
    return found


if __name__ == '__main__':
    d = collect()
    print(len(d), 'strings')
    if len(sys.argv) > 1:
        for s in sorted(d):
            print(s)
