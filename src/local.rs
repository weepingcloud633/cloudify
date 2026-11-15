//! Music files on this computer: scan folders, read tags, hand the result to the UI as tracks whose
//! id is `local:<path>` (the audio thread plays those straight from disk).
use lofty::prelude::*;
use serde_json::{json, Value};
use std::path::Path;

const EXT: [&str; 8] = ["mp3", "flac", "m4a", "mp4", "aac", "ogg", "wav", "alac"];
const MAX_FILES: usize = 6000;

fn walk(dir: &Path, depth: u32, out: &mut Vec<std::path::PathBuf>) {
    if depth > 6 || out.len() >= MAX_FILES {
        return;
    }
    let Ok(rd) = std::fs::read_dir(dir) else { return };
    for e in rd.flatten() {
        let p = e.path();
        if p.is_dir() {
            walk(&p, depth + 1, out);
        } else if p.extension().is_some_and(|x| EXT.contains(&x.to_string_lossy().to_lowercase().as_str())) {
            out.push(p);
        }
        if out.len() >= MAX_FILES {
            return;
        }
    }
}

fn track(p: &Path) -> Option<Value> {
    let name = p.file_stem()?.to_string_lossy().into_owned();
    let (mut title, mut artist, mut album, mut dur) = (name, String::new(), String::new(), 0u64);
    if let Ok(tf) = lofty::read_from_path(p) {
        dur = tf.properties().duration().as_secs();
        if let Some(t) = tf.primary_tag().or_else(|| tf.first_tag()) {
            if let Some(x) = t.title() {
                title = x.to_string();
            }
            artist = t.artist().map(|x| x.to_string()).unwrap_or_default();
            album = t.album().map(|x| x.to_string()).unwrap_or_default();
        }
    }
    if artist.is_empty() {
        artist = "Unknown artist".into();
    }
    Some(json!({"id": format!("local:{}", p.to_string_lossy()), "title": title, "artist": artist, "album": album, "dur": dur, "thumb": ""}))
}

/// Every music file under `folders`, sorted by artist then title.
pub fn scan(folders: &[String]) -> Vec<Value> {
    let mut files = Vec::new();
    for f in folders {
        walk(Path::new(f), 0, &mut files);
    }
    files.sort();
    files.dedup();
    let mut out: Vec<Value> = files.iter().filter_map(|p| track(p)).collect();
    out.sort_by(|a, b| {
        let k = |v: &Value| format!("{} {}", v["artist"].as_str().unwrap_or("").to_lowercase(), v["title"].as_str().unwrap_or("").to_lowercase());
        k(a).cmp(&k(b))
    });
    out
}

/// The folders to scan: the ones the person added, or their Music folder.
pub fn folders() -> Vec<String> {
    let s = crate::settings::get();
    let mut v: Vec<String> = s["localFolders"].as_array().into_iter().flatten().filter_map(|x| x.as_str().map(String::from)).collect();
    if v.is_empty() {
        if let Some(h) = std::env::var_os("USERPROFILE") {
            v.push(Path::new(&h).join("Music").to_string_lossy().into_owned());
        }
    }
    v
}
