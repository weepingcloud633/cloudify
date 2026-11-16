import re
def edit(path, pairs):
    t = open(path, encoding='utf-8').read()
    for a, b in pairs:
        if a not in t: print('MISSING', path, a[:50]); continue
        t = t.replace(a, b)
    open(path, 'w', encoding='utf-8').write(t)
edit(r'qml\HomeView.qml', [
 ('return h < 5 ? "Up late…" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"', 'return h < 5 ? Tr.t("Up late…") : h < 12 ? Tr.t("Good morning") : h < 18 ? Tr.t("Good afternoon") : Tr.t("Good evening")'),
 ('r.app.lib.liked.length + " liked"', 'r.app.lib.liked.length + " " + Tr.t("liked")'),
 ('(r.app.lib.playlists.length === 1 ? " collection" : " collections")', '(" " + (r.app.lib.playlists.length === 1 ? Tr.t("collection") : Tr.t("collections")))'),
 ('pc.modelData.tracks.length + " songs"', 'pc.modelData.tracks.length + " " + Tr.t("songs")'),
])
edit(r'qml\TracksPage.qml', [
 ('cell.pl.tracks.length + (cell.pl.tracks.length === 1 ? " song" : " songs")', 'cell.pl.tracks.length + " " + (cell.pl.tracks.length === 1 ? Tr.t("song") : Tr.t("songs"))'),
 ('r.tracks.length + (r.tracks.length === 1 ? " song" : " songs")', 'r.tracks.length + " " + (r.tracks.length === 1 ? Tr.t("song") : Tr.t("songs"))'),
 ('Math.floor(m / 60) + " hr " + (m % 60) + " min" : m + " min"', 'Math.floor(m / 60) + " " + Tr.t("hr") + " " + (m % 60) + " " + Tr.t("min") : m + " " + Tr.t("min")'),
])
edit(r'qml\StatsView.qml', [
 ('if (m < 60) return m + " min"', 'if (m < 60) return m + " " + Tr.t("min")'),
 ('Math.floor(m / 60) + " h " + (m % 60) + " min"', 'Math.floor(m / 60) + " " + Tr.t("h") + " " + (m % 60) + " " + Tr.t("min")'),
])
edit(r'qml\Main.qml', [
 ('note = minutes > 0 ? "Sleep timer: " + minutes + " min" : "Sleep timer off"', 'note = minutes > 0 ? Tr.t("Sleep timer: ") + minutes + " " + Tr.t("min") : Tr.t("Sleep timer off")'),
 ('note = r.total ? "Imported " + r.found + " of " + r.total + " songs" : "Imported"', 'note = r.total ? Tr.t("Imported ") + r.found + " / " + r.total : Tr.t("Imported")'),
])
# add the new strings to the dictionary source
p = open(r'tools\langs.py', encoding='utf-8').read()
extra = '''    "Up late…": ("Despierto hasta tarde…", "Encore debout…", "Noch wach…", "Acordado até tarde…", "Не спится…", "مستيقظ حتى وقت متأخر…"),
    "Good morning": ("Buenos días", "Bonjour", "Guten Morgen", "Bom dia", "Доброе утро", "صباح الخير"),
    "Good afternoon": ("Buenas tardes", "Bon après-midi", "Guten Tag", "Boa tarde", "Добрый день", "مساء الخير"),
    "Good evening": ("Buenas noches", "Bonsoir", "Guten Abend", "Boa noite", "Добрый вечер", "مساء الخير"),
    "liked": ("me gustan", "likés", "geliked", "curtidas", "понравилось", "مفضلة"),
    "collection": ("colección", "collection", "Sammlung", "coleção", "коллекция", "مجموعة"),
    "collections": ("colecciones", "collections", "Sammlungen", "coleções", "коллекции", "مجموعات"),
    "song": ("canción", "titre", "Song", "música", "песня", "أغنية"),
    "songs": ("canciones", "titres", "Songs", "músicas", "песен", "أغنية"),
    "hr": ("h", "h", "Std.", "h", "ч", "س"),
    "h": ("h", "h", "Std.", "h", "ч", "س"),
    "min": ("min", "min", "Min.", "min", "мин", "د"),
    "Sleep timer: ": ("Temporizador: ", "Minuteur : ", "Schlaftimer: ", "Temporizador: ", "Таймер сна: ", "مؤقت النوم: "),
    "Sleep timer off": ("Temporizador desactivado", "Minuteur désactivé", "Schlaftimer aus", "Temporizador desativado", "Таймер сна выключен", "تم إيقاف مؤقت النوم"),
    "Imported ": ("Importadas ", "Importés ", "Importiert ", "Importadas ", "Импортировано ", "تم استيراد "),
    "Saved Daft Punk": ("Saved Daft Punk", "Saved Daft Punk", "Saved Daft Punk", "Saved Daft Punk", "Saved Daft Punk", "Saved Daft Punk"),
'''
p = p.replace('    "Language": ("Idioma"', extra + '    "Language": ("Idioma"', 1)
open(r'tools\langs.py', 'w', encoding='utf-8').write(p)
