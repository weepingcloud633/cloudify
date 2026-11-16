"""Wrap the visible English strings of the QML files in Tr.t(...).  `python tools/wrap_tr.py list` only lists them."""
import glob
import re
import sys

KEYS = r'(?:text|title|hint|heading|placeholderText|label|button|button2|t|n)'
A = re.compile(r'(\b' + KEYS + r':\s*)"([^"\\\n]{2,90})"')
KEYLINE = re.compile(r'\b(?:text|title|hint|heading|placeholderText|label|button|button2):')
B = re.compile(r'(\?|\|\||\s:)\s*"([A-Z][^"\\\n]{2,70})"')
D = re.compile(r'(\b(?:note|updateMsg|mixNote)\s*=\s*)"([^"\\\n]{2,90})"')
SKIP = ('Themes.qml', 'ProfileGate.qml', 'Tr.qml', 'Langs.qml')


def ok(s):
    if not re.search(r'[A-Za-z]{2}', s):
        return False
    if re.fullmatch(r'[a-z_0-9.]+', s):  # icon names, ids
        return False
    if s.startswith(('qrc:', 'http', '#', 'file:', 'Cloudify')) and s != 'Cloudify':
        return False
    return True


def process(text, found):
    def ra(m):
        if not ok(m.group(2)):
            return m.group(0)
        found.add(m.group(2))
        return m.group(1) + 'Tr.t("' + m.group(2) + '")'

    def rd(m):
        if not ok(m.group(2)):
            return m.group(0)
        found.add(m.group(2))
        return m.group(1) + 'Tr.t("' + m.group(2) + '")'

    out = []
    for line in text.split('\n'):
        if 'Tr.t(' not in line:
            line = A.sub(ra, line)
            line = D.sub(rd, line)
        # ternaries inside a text binding
        km = KEYLINE.search(line)
        if km:
            head, tail = line[:km.end()], line[km.end():]

            def rb(m):
                if not ok(m.group(2)):
                    return m.group(0)
                found.add(m.group(2))
                return m.group(1) + ' Tr.t("' + m.group(2) + '")'

            tail = B.sub(rb, tail)
            line = head + tail
        out.append(line)
    return '\n'.join(out)


def main():
    found = set()
    for f in sorted(glob.glob('qml/*.qml')):
        if f.endswith(SKIP):
            continue
        t = open(f, encoding='utf-8').read()
        n = process(t, found)
        if n != t and len(sys.argv) < 2:
            open(f, 'w', encoding='utf-8').write(n)
    print(len(found), 'strings', file=sys.stderr)
    with open('shots/strings.txt', 'w', encoding='utf-8') as o:
        o.write('\n'.join(sorted(found)))


main()
