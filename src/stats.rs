//! Listening history: one line per finished play, summed up for the Stats page.
use crate::profiles;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::Write;

fn file() -> std::path::PathBuf {
    profiles::dir().join("plays.jsonl")
}

fn now() -> u64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

/// Record that `secs` seconds of a song were heard.
pub fn log_play(track: &Value, secs: u64) {
    let id = track["id"].as_str().unwrap_or("");
    if id.is_empty() || secs < 20 {
        return;
    }
    let line = json!({"t": now(), "id": id, "title": track["title"], "artist": track["artist"], "thumb": track["thumb"], "secs": secs});
    // keep the file small: past 3 MB the older half goes
    if std::fs::metadata(file()).map(|m| m.len() > 3_000_000).unwrap_or(false) {
        if let Ok(text) = std::fs::read_to_string(file()) {
            let lines: Vec<&str> = text.lines().collect();
            let _ = std::fs::write(file(), lines[lines.len() / 2..].join("\n") + "\n");
        }
    }
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(file()) {
        let _ = writeln!(f, "{line}");
    }
}

/// `{totalSecs, plays, weekSecs, songs:[{id,title,artist,thumb,plays}], artists:[{name,secs,plays}], days:[secs x14]}`
pub fn summary() -> Value {
    let text = std::fs::read_to_string(file()).unwrap_or_default();
    let off = crate::paths::utc_offset_secs();
    let today = (now() as i64 + off) / 86400;
    let (mut total, mut plays, mut week) = (0u64, 0u64, 0u64);
    let mut songs: HashMap<String, (Value, u64)> = HashMap::new();
    let mut artists: HashMap<String, (u64, u64)> = HashMap::new();
    let mut days = [0u64; 14];
    for l in text.lines() {
        let Ok(v) = serde_json::from_str::<Value>(l) else { continue };
        let secs = v["secs"].as_u64().unwrap_or(0);
        let day = (v["t"].as_u64().unwrap_or(0) as i64 + off) / 86400;
        total += secs;
        plays += 1;
        let ago = today - day;
        if (0..7).contains(&ago) {
            week += secs;
        }
        if (0..14).contains(&ago) {
            days[(13 - ago) as usize] += secs;
        }
        let e = songs.entry(v["id"].as_str().unwrap_or("").to_string()).or_insert((v.clone(), 0));
        e.1 += 1;
        let name = v["artist"].as_str().unwrap_or("").split([',', '&']).next().unwrap_or("").trim().to_string();
        if !name.is_empty() {
            let a = artists.entry(name).or_default();
            a.0 += secs;
            a.1 += 1;
        }
    }
    let mut s: Vec<_> = songs.into_values().collect();
    s.sort_by(|a, b| b.1.cmp(&a.1));
    let mut a: Vec<_> = artists.into_iter().collect();
    a.sort_by(|x, y| y.1 .0.cmp(&x.1 .0));
    json!({
        "totalSecs": total, "plays": plays, "weekSecs": week,
        "songs": s.iter().take(10).map(|(v, n)| json!({"id": v["id"], "title": v["title"], "artist": v["artist"], "thumb": v["thumb"], "plays": n})).collect::<Vec<_>>(),
        "artists": a.iter().take(10).map(|(n, (secs, p))| json!({"name": n, "secs": secs, "plays": p})).collect::<Vec<_>>(),
        "days": days,
    })
}
