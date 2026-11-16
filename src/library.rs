//! Playlists, liked songs, share codes and playlist import.
use crate::ytm;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use flate2::{read::ZlibDecoder, write::ZlibEncoder, Compression};
use serde_json::{json, Value};
use std::io::{Read, Write};
use std::sync::Mutex;

pub const CODE_PREFIX: &str = "CLOUD-";
const MAX_CODE: u64 = 40 * 1024 * 1024;

static LIB: Mutex<Option<Value>> = Mutex::new(None);

fn file() -> std::path::PathBuf {
    crate::profiles::dir().join("library.json")
}

/// Forget the cached library (after a profile switch).
pub fn reset() {
    *LIB.lock().unwrap() = None;
}

fn with<R>(f: impl FnOnce(&mut Value) -> R) -> R {
    let mut g = LIB.lock().unwrap();
    let v = g.get_or_insert_with(|| {
        std::fs::read(file())
            .ok()
            .and_then(|b| serde_json::from_slice(&b).ok())
            .unwrap_or_else(|| json!({"liked": [], "playlists": []}))
    });
    let r = f(v);
    let tmp = file().with_extension("tmp");
    if std::fs::write(&tmp, serde_json::to_vec(v).unwrap_or_default()).is_ok() {
        let _ = std::fs::rename(&tmp, file());
    }
    r
}

fn new_id() -> String {
    let t = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    format!("{:x}", t)
}

/// Keep only the fields a share file needs.
fn slim(t: &Value) -> Value {
    json!({
        "id": t["id"], "title": t["title"], "artist": t["artist"],
        "album": t["album"], "dur": t["dur"], "thumb": t["thumb"],
    })
}

pub fn snapshot() -> Value {
    with(|v| v.clone())
}

pub fn create_playlist(name: &str, tracks: Vec<Value>, desc: &str) -> Value {
    let pl = json!({"id": new_id(), "name": name, "desc": desc, "tracks": tracks.iter().map(slim).collect::<Vec<_>>()});
    with(|v| v["playlists"].as_array_mut().unwrap().insert(0, pl.clone()));
    pl
}

pub fn add_to_playlist(id: &str, track: &Value) {
    with(|v| {
        if let Some(pl) = v["playlists"].as_array_mut().and_then(|a| a.iter_mut().find(|p| p["id"] == id)) {
            let list = pl["tracks"].as_array_mut().unwrap();
            if !list.iter().any(|t| t["id"] == track["id"]) {
                list.push(slim(track));
            }
        }
    });
}

pub fn remove_from_playlist(id: &str, song: &str) {
    with(|v| {
        if let Some(pl) = v["playlists"].as_array_mut().and_then(|a| a.iter_mut().find(|p| p["id"] == id)) {
            pl["tracks"].as_array_mut().unwrap().retain(|t| t["id"] != song);
        }
    });
}

pub fn delete_playlist(id: &str) {
    with(|v| v["playlists"].as_array_mut().unwrap().retain(|p| p["id"] != id));
}

fn local_path(src: &str) -> String {
    let s = src.strip_prefix("file:///").unwrap_or(src);
    let mut out = Vec::new();
    let b = s.as_bytes();
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() + 0 && i + 2 <= b.len() - 1 {
            if let Ok(v) = u8::from_str_radix(&s[i + 1..i + 3], 16) {
                out.push(v);
                i += 3;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// Centre-crop a picked image to a square cover and keep it in the profile folder.
fn store_cover(id: &str, src: &str) -> Result<String, String> {
    let path = local_path(src);
    let img = image::open(&path).map_err(|e| format!("That image could not be used: {e}"))?;
    let side = img.width().min(img.height()).max(1);
    let sq = img.crop_imm((img.width() - side) / 2, (img.height() - side) / 2, side, side).resize(512, 512, image::imageops::FilterType::Lanczos3);
    let dir = crate::profiles::dir().join("covers");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    // a new file name makes the image reload when the cover changes; older covers of this playlist go
    if let Ok(rd) = std::fs::read_dir(&dir) {
        for e in rd.flatten() {
            if e.file_name().to_string_lossy().starts_with(&format!("{id}-")) {
                let _ = std::fs::remove_file(e.path());
            }
        }
    }
    let out = dir.join(format!("{id}-{stamp}.jpg"));
    sq.to_rgb8().save_with_format(&out, image::ImageFormat::Jpeg).map_err(|e| e.to_string())?;
    Ok(format!("file:///{}", out.to_string_lossy().replace('\\', "/")))
}

/// Create (empty `id`) or edit a playlist. `cover`: "" keeps it, "none" clears it, "design:N" picks a
/// generated design, anything else is an image file.
pub fn save_playlist(id: &str, name: &str, desc: &str, cover: &str) -> Result<Value, String> {
    let name = name.trim();
    if name.is_empty() {
        return Err("Give the playlist a name".into());
    }
    let id = if id.is_empty() { create_playlist(name, vec![], desc)["id"].as_str().unwrap_or("").to_string() } else { id.to_string() };
    let cover_val = match cover {
        "" => None,
        "none" => Some(String::new()),
        c if c.starts_with("design:") && c[7..].bytes().all(|b| b.is_ascii_digit()) && c.len() < 12 => Some(c.to_string()),
        c => Some(store_cover(&id, c)?),
    };
    with(|v| {
        let pl = v["playlists"].as_array_mut().and_then(|a| a.iter_mut().find(|p| p["id"] == id.as_str()))?;
        pl["name"] = json!(name);
        pl["desc"] = json!(desc.chars().take(300).collect::<String>());
        if let Some(c) = cover_val {
            pl["cover"] = json!(c);
        }
        Some(pl.clone())
    })
    .ok_or_else(|| "Playlist not found".to_string())
}

/// Mark a song as "disliked" (never recommended) or "excluded" (left out of the taste profile).
/// `kind` is one of those two words; an empty `id` with `on == false` clears the whole list.
pub fn set_flag(kind: &str, id: &str, on: bool) {
    if kind != "disliked" && kind != "excluded" {
        return;
    }
    with(|v| {
        if !v[kind].is_array() {
            v[kind] = json!([]);
        }
        let list = v[kind].as_array_mut().unwrap();
        if id.is_empty() {
            if !on {
                list.clear();
            }
            return;
        }
        list.retain(|x| x.as_str() != Some(id));
        if on {
            list.push(json!(id));
        }
        // a song you dislike is no longer a song you like
        if kind == "disliked" && on {
            if let Some(liked) = v["liked"].as_array_mut() {
                liked.retain(|t| t["id"].as_str() != Some(id));
            }
        }
    });
}

/// Ids a kind of flag holds ("disliked" or "excluded").
pub fn flagged(kind: &str) -> std::collections::HashSet<String> {
    with(|v| v[kind].as_array().map(|a| a.iter().filter_map(|x| x.as_str().map(String::from)).collect()).unwrap_or_default())
}

/// Hide a song in one playlist (it stays in the playlist, out of sight) or show it again.
pub fn hide_in_playlist(playlist: &str, song: &str, on: bool) {
    with(|v| {
        if let Some(pl) = v["playlists"].as_array_mut().and_then(|a| a.iter_mut().find(|p| p["id"] == playlist)) {
            if !pl["hidden"].is_array() {
                pl["hidden"] = json!([]);
            }
            let list = pl["hidden"].as_array_mut().unwrap();
            list.retain(|x| x.as_str() != Some(song));
            if on {
                list.push(json!(song));
            }
        }
    });
}

/// Pin or unpin a playlist in the sidebar.
pub fn toggle_pin(id: &str) {
    with(|v| {
        if let Some(pl) = v["playlists"].as_array_mut().and_then(|a| a.iter_mut().find(|p| p["id"] == id)) {
            let on = pl["pinned"].as_bool().unwrap_or(false);
            pl["pinned"] = json!(!on);
        }
    });
}

pub fn toggle_like(track: &Value) -> bool {
    with(|v| {
        let liked = v["liked"].as_array_mut().unwrap();
        if let Some(i) = liked.iter().position(|t| t["id"] == track["id"]) {
            liked.remove(i);
            false
        } else {
            liked.insert(0, slim(track));
            true
        }
    })
}

// ---- share codes and files ----

pub fn playlist_payload(id: &str, by: &str) -> Option<Value> {
    with(|v| {
        let pl = v["playlists"].as_array()?.iter().find(|p| p["id"] == id)?;
        Some(json!({"app": "cloud-music", "v": 1, "kind": "playlist", "name": pl["name"], "desc": pl["desc"], "by": by, "tracks": pl["tracks"]}))
    })
}

pub fn encode(obj: &Value, strip_thumbs: bool) -> String {
    let mut o = obj.clone();
    if strip_thumbs {
        if let Some(a) = o["tracks"].as_array_mut() {
            a.iter_mut().for_each(|t| t["thumb"] = json!(""));
        }
    }
    let raw = serde_json::to_vec(&o).unwrap_or_default();
    let mut z = ZlibEncoder::new(Vec::new(), Compression::best());
    let _ = z.write_all(&raw);
    format!("{CODE_PREFIX}{}", URL_SAFE_NO_PAD.encode(z.finish().unwrap_or_default()))
}

/// Accepts a CLOUD- code, or the raw JSON of a .cloud file.
pub fn decode(text: &str) -> Result<Value, String> {
    let s = text.trim();
    let obj: Value = if let Some(i) = s.find(CODE_PREFIX) {
        let body: String = s[i + CODE_PREFIX.len()..]
            .chars()
            .take_while(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
            .collect();
        let bytes = URL_SAFE_NO_PAD.decode(body.trim_end_matches('=')).map_err(|_| "Code is damaged")?;
        let mut raw = Vec::new();
        ZlibDecoder::new(&bytes[..]).take(MAX_CODE).read_to_end(&mut raw).map_err(|_| "Code is damaged")?;
        serde_json::from_slice(&raw).map_err(|_| "Code is damaged")?
    } else {
        serde_json::from_str(s).map_err(|_| "Not a Cloudify share")?
    };
    match obj["app"].as_str() {
        Some("cloud-music") => Ok(obj),
        _ => Err("Not a Cloudify share".into()),
    }
}

pub fn import_payload(obj: &Value) -> Result<Value, String> {
    match obj["kind"].as_str() {
        Some("playlist") => {
            let tracks = obj["tracks"].as_array().cloned().unwrap_or_default();
            let name = obj["name"].as_str().unwrap_or("Imported playlist");
            Ok(create_playlist(name, tracks, obj["desc"].as_str().unwrap_or("")))
        }
        Some("profile") => {
            let mut first = Value::Null;
            for p in obj["playlists"].as_array().cloned().unwrap_or_default() {
                let pl = create_playlist(p["name"].as_str().unwrap_or("Playlist"), p["tracks"].as_array().cloned().unwrap_or_default(), p["desc"].as_str().unwrap_or(""));
                if first.is_null() {
                    first = pl;
                }
            }
            for t in obj["liked"].as_array().cloned().unwrap_or_default().iter().rev() {
                with(|v| {
                    let liked = v["liked"].as_array_mut().unwrap();
                    if !liked.iter().any(|x| x["id"] == t["id"]) {
                        liked.insert(0, slim(t));
                    }
                });
            }
            Ok(first)
        }
        _ => Err("Unknown share type".into()),
    }
}

// ---- reading a playlist from CSV or pasted lines ----

pub struct Wanted {
    pub title: String,
    pub artist: String,
    pub dur: u32,
    pub raw: String,
}

pub struct Parsed {
    pub name: String,
    pub songs: Vec<Wanted>,
}

fn parse_csv(text: &str) -> Vec<Vec<String>> {
    let mut rows = Vec::new();
    let (mut row, mut cell, mut q) = (Vec::new(), String::new(), false);
    let mut it = text.chars().peekable();
    while let Some(c) = it.next() {
        if q {
            if c == '"' {
                if it.peek() == Some(&'"') {
                    cell.push('"');
                    it.next();
                } else {
                    q = false;
                }
            } else {
                cell.push(c);
            }
        } else if c == '"' {
            q = true;
        } else if c == ',' || c == ';' || c == '\t' {
            row.push(std::mem::take(&mut cell));
        } else if c == '\n' || c == '\r' {
            if c == '\r' && it.peek() == Some(&'\n') {
                it.next();
            }
            row.push(std::mem::take(&mut cell));
            if row.iter().any(|x| !x.trim().is_empty()) {
                rows.push(std::mem::take(&mut row));
            } else {
                row.clear();
            }
        } else {
            cell.push(c);
        }
    }
    row.push(cell);
    if row.iter().any(|x| !x.trim().is_empty()) {
        rows.push(row);
    }
    rows
}

pub fn from_csv(text: &str) -> Option<Parsed> {
    let rows = parse_csv(text.trim_start_matches('\u{feff}'));
    if rows.len() < 2 {
        return None;
    }
    let head: Vec<String> = rows[0].iter().map(|x| x.trim().to_lowercase()).collect();
    let col = |names: &[&str]| -> Option<usize> {
        names
            .iter()
            .find_map(|n| head.iter().position(|x| x == n))
            .or_else(|| names.iter().find_map(|n| head.iter().position(|x| x.contains(n))))
    };
    let ti = col(&["track name", "title", "song", "name", "track"])?;
    let ai = col(&["artist name(s)", "artist name", "artists", "artist"]);
    let di = col(&["duration (ms)", "duration_ms", "duration"]);
    let pi = col(&["playlist name", "playlist"]);
    let cell = |r: &Vec<String>, i: Option<usize>| i.and_then(|i| r.get(i)).map(|s| s.trim().to_string()).unwrap_or_default();
    let songs = rows[1..]
        .iter()
        .filter_map(|r| {
            let title = cell(r, Some(ti));
            if title.is_empty() {
                return None;
            }
            let mut dur: f64 = cell(r, di).parse().unwrap_or(0.0);
            if dur > 10000.0 {
                dur /= 1000.0;
            }
            let artist = cell(r, ai).split([',', ';']).next().unwrap_or("").trim().to_string();
            Some(Wanted { title, artist, dur: dur.round() as u32, raw: String::new() })
        })
        .collect();
    Some(Parsed { name: cell(&rows[1], pi), songs })
}

pub fn from_lines(text: &str) -> Parsed {
    let mut songs = Vec::new();
    for line in text.lines() {
        let mut l = line.trim();
        if l.is_empty() || l.contains("open.spotify.com/") {
            continue;
        }
        l = l.trim_start_matches(|c: char| c.is_ascii_digit()).trim_start_matches(['.', ')', ':', '-', '*', '•', ' ']);
        let (mut title, mut artist) = (l.to_string(), String::new());
        if let Some((a, t)) = l.split_once(" - ").or_else(|| l.split_once(" – ")).or_else(|| l.split_once(" — ")) {
            artist = a.trim().into();
            title = t.trim().into();
        } else if let Some((t, a)) = l.rsplit_once(" by ") {
            title = t.trim().into();
            artist = a.trim().into();
        }
        songs.push(Wanted { title, artist, dur: 0, raw: l.to_string() });
    }
    Parsed { name: String::new(), songs }
}

fn norm(s: &str) -> String {
    let mut out = String::new();
    let mut depth = 0;
    for c in s.to_lowercase().chars() {
        match c {
            '(' | '[' => depth += 1,
            ')' | ']' => depth = (depth - 1).max(0),
            _ if depth > 0 => {}
            c if c.is_alphanumeric() => out.push(c),
            _ => out.push(' '),
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Find the best catalog match for a wanted song (title + artist + length scoring).
pub fn match_song(w: &Wanted) -> Option<Value> {
    let q = if w.artist.is_empty() { if w.raw.is_empty() { w.title.clone() } else { w.raw.clone() } } else { format!("{} {}", w.title, w.artist) };
    let found = ytm::search_songs(&q.chars().take(150).collect::<String>()).ok()?;
    let (nt, na) = (norm(&w.title), norm(&w.artist));
    let mut best: Option<(i32, Value)> = None;
    for (i, x) in found.as_array()?.iter().take(8).enumerate() {
        let (xt, xa) = (norm(x["title"].as_str().unwrap_or("")), norm(x["artist"].as_str().unwrap_or("")));
        let mut sc = -(i as i32) * 2;
        let title_ok = xt == nt || xt.contains(&nt) || nt.contains(&xt);
        let artist_ok = !na.is_empty() && xa.contains(&na);
        if xt == nt {
            sc += 30;
        } else if title_ok {
            sc += 15;
        }
        if artist_ok {
            sc += 20;
        }
        let d = x["dur"].as_u64().unwrap_or(0) as i64;
        if w.dur > 0 && d > 0 {
            let diff = (d - w.dur as i64).abs();
            sc += if diff <= 3 { 18 } else if diff <= 8 { 8 } else if diff > 40 { -15 } else { 0 };
        }
        if !title_ok && !artist_ok {
            sc -= 100;
        }
        if best.as_ref().map_or(true, |b| sc > b.0) {
            best = Some((sc, x.clone()));
        }
    }
    best.filter(|b| b.0 > -50).map(|b| b.1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn code_roundtrip() {
        let obj = json!({"app": "cloud-music", "v": 1, "kind": "playlist", "name": "x", "tracks": [{"id": "a", "title": "T", "artist": "A", "album": "", "dur": 3, "thumb": "u"}]});
        let code = encode(&obj, true);
        assert!(code.starts_with("CLOUD-"));
        assert_eq!(decode(&code).unwrap()["tracks"][0]["thumb"], "");
        assert!(decode(&format!("hi {code} bye")).is_ok());
        assert!(decode("CLOUD-!!!").is_err());
    }

    #[test]
    fn csv_and_lines() {
        let p = from_csv("Track URI,Track Name,Artist Name(s),Duration (ms)\nx,\"Blinding, Lights\",\"The Weeknd;Other\",200040\n").unwrap();
        assert_eq!(p.songs[0].title, "Blinding, Lights");
        assert_eq!(p.songs[0].artist, "The Weeknd");
        assert_eq!(p.songs[0].dur, 200);
        let l = from_lines("1. Daft Punk - Get Lucky\nGet Lucky by Daft Punk\n");
        assert_eq!((l.songs[0].artist.as_str(), l.songs[0].title.as_str()), ("Daft Punk", "Get Lucky"));
        assert_eq!(l.songs[1].artist, "Daft Punk");
    }
}
