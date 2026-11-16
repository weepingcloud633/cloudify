"""Add more colour themes to qml/Themes.qml (after the 16 from Swiftify). Safe to run again.

Each theme is a dark base, text and three accents; the light variant and every surface in between
is worked out from them. Slots: background, surface low, surface, container, container high,
container highest, text, subtext, outline, primary, secondary, tertiary, error.
"""
import colorsys
import json
import re

# id, name, dark bg, text, primary, secondary, tertiary
THEMES = [
    ("monokai", "Monokai", "#272822", "#f8f8f2", "#a6e22e", "#66d9ef", "#f92672"),
    ("monokai-pro", "Monokai Pro", "#2d2a2e", "#fcfcfa", "#ffd866", "#78dce8", "#ff6188"),
    ("ayu-dark", "Ayu Dark", "#0b0e14", "#bfbdb6", "#e6b450", "#59c2ff", "#aad94c"),
    ("ayu-mirage", "Ayu Mirage", "#1f2430", "#cccac2", "#ffcc66", "#73d0ff", "#d5ff80"),
    ("material-ocean", "Material Ocean", "#0f111a", "#a6accd", "#82aaff", "#c792ea", "#c3e88d"),
    ("material-darker", "Material Darker", "#212121", "#eeffff", "#82aaff", "#c3e88d", "#f78c6c"),
    ("palenight", "Palenight", "#292d3e", "#a6accd", "#82aaff", "#c792ea", "#ffcb6b"),
    ("night-owl", "Night Owl", "#011627", "#d6deeb", "#82aaff", "#c792ea", "#addb67"),
    ("cobalt2", "Cobalt2", "#193549", "#ffffff", "#ffc600", "#0088ff", "#ff628c"),
    ("synthwave", "Synthwave '84", "#262335", "#ffffff", "#ff7edb", "#36f9f6", "#fede5d"),
    ("oceanic-next", "Oceanic Next", "#1b2b34", "#d8dee9", "#6699cc", "#99c794", "#fac863"),
    ("github-dark", "GitHub Dark", "#0d1117", "#e6edf3", "#58a6ff", "#3fb950", "#d2a8ff"),
    ("github-dimmed", "GitHub Dimmed", "#22272e", "#adbac7", "#539bf5", "#57ab5a", "#b083f0"),
    ("zenburn", "Zenburn", "#3f3f3f", "#dcdccc", "#f0dfaf", "#8cd0d3", "#cc9393"),
    ("moonlight", "Moonlight", "#212337", "#c8d3f5", "#82aaff", "#c099ff", "#ffc777"),
    ("poimandres", "Poimandres", "#1b1e28", "#a6accd", "#5de4c7", "#add7ff", "#fffac2"),
    ("vesper", "Vesper", "#101010", "#ffffff", "#ffc799", "#99ffe4", "#a0a0a0"),
    ("horizon", "Horizon", "#1c1e26", "#d5d8da", "#e95678", "#25b0bc", "#fab795"),
    ("andromeda", "Andromeda", "#23262e", "#d5ced9", "#00e8c6", "#c74ded", "#ffe66d"),
    ("shades-of-purple", "Shades of Purple", "#2d2b55", "#ffffff", "#fad000", "#a599e9", "#ff628c"),
    ("panda", "Panda", "#292a2b", "#e6e6e6", "#ff75b5", "#19f9d8", "#ffb86c"),
    ("midnight", "Midnight", "#0a0a14", "#e8e8f0", "#7c5cff", "#4cc9f0", "#ff6b9d"),
    ("sunset", "Sunset", "#1a1016", "#f5e6e0", "#ff7a45", "#ffb347", "#ff5c8a"),
    ("forest", "Forest", "#0f1a14", "#e0efe5", "#4cd68a", "#a3e635", "#34d1bf"),
    ("ocean", "Ocean", "#08161f", "#dff1fa", "#38bdf8", "#22d3ee", "#818cf8"),
    ("rose", "Rose", "#1c0f14", "#fce7ef", "#fb7185", "#f472b6", "#fdba74"),
    ("lavender", "Lavender", "#16121f", "#ece6ff", "#a78bfa", "#c084fc", "#f0abfc"),
    ("mint", "Mint", "#0d1a18", "#e0f5f0", "#5eead4", "#86efac", "#7dd3fc"),
    ("amber", "Amber", "#1a1408", "#fdf1d6", "#fbbf24", "#fb923c", "#facc15"),
    ("crimson", "Crimson", "#1a0a0c", "#fbe4e6", "#ef4444", "#f97316", "#f43f5e"),
    ("graphite", "Graphite", "#121212", "#e5e5e5", "#bdbdbd", "#9e9e9e", "#e0e0e0"),
    ("sakura", "Sakura", "#1f1519", "#fbe9ef", "#f9a8d4", "#fecdd3", "#fde68a"),
    ("aurora", "Aurora", "#0b1020", "#e6edff", "#34d399", "#60a5fa", "#c084fc"),
    ("candy", "Candy", "#1b1226", "#f9e8ff", "#ff6bd6", "#6bd5ff", "#fff06b"),
    ("espresso", "Espresso", "#1b1410", "#f1e4d8", "#d4a373", "#e9c46a", "#c97b63"),
    ("neon", "Neon", "#07070d", "#f2f2ff", "#39ff88", "#00e5ff", "#ff2bd6"),
    ("slate", "Slate", "#1e2530", "#dde4ee", "#7aa2d6", "#8fbf9f", "#d6a77a"),
    ("coffee", "Coffee", "#211a16", "#eadfd4", "#c8956d", "#a8b8a0", "#d9b779"),
    ("cherry", "Cherry", "#190b10", "#fde8ee", "#e11d48", "#fb7185", "#fda4af"),
    ("arctic", "Arctic", "#0e1822", "#e3f1fb", "#7dd3fc", "#a5f3fc", "#c4b5fd"),
    ("matcha", "Matcha", "#141a12", "#e8f0dc", "#a3c35a", "#7fb685", "#d9c66a"),
    ("twilight", "Twilight", "#161326", "#e9e4ff", "#9d8cff", "#ff8fb1", "#ffd28f"),
]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexs(c):
    return "#" + "".join(f"{max(0, min(255, round(x * 255))):02x}" for x in c)


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def tone(c, lightness=None, sat_mul=1.0):
    h, l, s = colorsys.rgb_to_hls(*c)
    if lightness is not None:
        l = lightness
    return colorsys.hls_to_rgb(h, l, min(1, s * sat_mul))


def dark_variant(bg, fg, p, s, t):
    bg, fg, p, s, t = map(rgb, (bg, fg, p, s, t))
    black = (0, 0, 0)
    return [hexs(mix(bg, black, 0.22)), hexs(mix(bg, black, 0.22)), hexs(bg), hexs(mix(bg, fg, 0.07)), hexs(mix(bg, fg, 0.12)), hexs(mix(bg, fg, 0.17)),
            hexs(fg), hexs(mix(fg, bg, 0.3)), hexs(mix(fg, bg, 0.62)), hexs(p), hexs(s), hexs(t), "#ff6b6b"]


def light_variant(bg, fg, p, s, t):
    bg, fg, p, s, t = map(rgb, (bg, fg, p, s, t))
    white = (1, 1, 1)
    base = mix(white, p, 0.05)
    text = tone(mix((0.05, 0.05, 0.07), p, 0.12), 0.12)
    def deep(c):
        return tone(c, min(0.46, max(0.30, colorsys.rgb_to_hls(*c)[1] * 0.62)), 1.0)
    return [hexs(mix(base, (0, 0, 0), 0.04)), hexs(mix(base, (0, 0, 0), 0.04)), hexs(base), hexs(mix(base, text, 0.07)), hexs(mix(base, text, 0.12)), hexs(mix(base, text, 0.17)),
            hexs(text), hexs(mix(text, base, 0.3)), hexs(mix(text, base, 0.58)), hexs(deep(p)), hexs(deep(s)), hexs(deep(t)), "#b3261e"]


def main():
    path = r"qml\Themes.qml"
    src = open(path, encoding="utf-8").read()
    m = re.search(r"families: (\[.*\])\n", src, re.S)
    fams = json.loads(m.group(1))
    have = {f["id"] for f in fams}
    added = 0
    for tid, name, bg, fg, p, s, t in THEMES:
        if tid in have:
            continue
        fams.append({"id": tid, "name": name, "light": light_variant(bg, fg, p, s, t), "dark": dark_variant(bg, fg, p, s, t)})
        added += 1
    out = src[:m.start(1)] + json.dumps(fams) + src[m.end(1):]
    open(path, "w", encoding="utf-8").write(out)
    print("added", added, "total", len(fams))


main()
