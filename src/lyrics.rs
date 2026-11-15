//! Synced lyrics from lrclib.net, cached on disk.
use crate::paths;
use serde_json::{json, Value};

const UA: &str = "CloudMusic/0.3 (by weepingcloud)";

fn enc(s: &str) -> String {
    let mut o = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) {
            o.push(b as char);
        } else {
            o.push_str(&format!("%{b:02X}"));
        }
    }
    o
}

fn get(url: &str) -> Option<Value> {
    ureq::get(url).set("User-Agent", UA).timeout(std::time::Duration::from_secs(12)).call().ok()?.into_json().ok()
}

/// "[01:23.45] text" lines to `[{t: ms, text}]`, sorted.
pub fn parse_lrc(lrc: &str) -> Vec<Value> {
    let mut out = Vec::new();
    for line in lrc.lines() {
        let mut rest = line.trim();
        let mut stamps = Vec::new();
        while let Some(r) = rest.strip_prefix('[') {
            let Some((tag, after)) = r.split_once(']') else { break };
            let ms = tag.split_once(':').and_then(|(m, s)| Some(m.parse::<f64>().ok()? * 60000.0 + s.parse::<f64>().ok()? * 1000.0));
            match ms {
                Some(ms) => stamps.push(ms as u64),
                None => break, // [ar:...] style tag
            }
            rest = after;
        }
        for t in stamps {
            out.push((t, rest.trim().to_string()));
        }
    }
    out.sort_by_key(|x| x.0);
    out.into_iter().map(|(t, text)| json!({"t": t, "text": text})).collect()
}

fn from_record(r: &Value) -> Option<Value> {
    if let Some(s) = r["syncedLyrics"].as_str().filter(|s| !s.trim().is_empty()) {
        let lines = parse_lrc(s);
        if !lines.is_empty() {
            return Some(json!({"synced": true, "lines": lines}));
        }
    }
    let plain = r["plainLyrics"].as_str().filter(|s| !s.trim().is_empty())?;
    let lines: Vec<Value> = plain.lines().map(|l| json!({"t": 0, "text": l.trim()})).collect();
    Some(json!({"synced": false, "lines": lines}))
}

pub fn fetch(vid: &str, title: &str, artist: &str, album: &str, dur: u64) -> Value {
    let cache = paths::dir("cache/lyrics").join(format!("{vid}.json"));
    if let Some(v) = std::fs::read(&cache).ok().and_then(|b| serde_json::from_slice::<Value>(&b).ok()) {
        return v;
    }
    let exact = format!(
        "https://lrclib.net/api/get?track_name={}&artist_name={}&album_name={}&duration={}",
        enc(title), enc(artist.split([',', '&']).next().unwrap_or(artist).trim()), enc(album), dur
    );
    let mut found = get(&exact).and_then(|r| from_record(&r));
    if found.is_none() {
        let q = format!("https://lrclib.net/api/search?track_name={}&artist_name={}", enc(title), enc(artist.split([',', '&']).next().unwrap_or(artist).trim()));
        if let Some(Value::Array(list)) = get(&q) {
            let mut best: Option<(i64, &Value)> = None;
            for r in &list {
                let d = r["duration"].as_f64().unwrap_or(0.0) as i64;
                let score = (if r["syncedLyrics"].is_string() { 0 } else { 100 }) + (d - dur as i64).abs();
                if best.map_or(true, |b| score < b.0) {
                    best = Some((score, r));
                }
            }
            found = best.filter(|b| b.0 < 120).and_then(|b| from_record(b.1));
        }
    }
    match found {
        Some(v) => {
            let _ = std::fs::write(&cache, serde_json::to_vec(&v).unwrap_or_default());
            v
        }
        None => json!({"synced": false, "lines": []}),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lrc_parsing() {
        let l = parse_lrc("[ar:X]\n[00:12.50] Hello\n[00:05.00][00:30.25] Echo\n[01:00.00]\n");
        assert_eq!(l[0]["text"], "Echo");
        assert_eq!(l[0]["t"], 5000);
        assert_eq!(l[1]["t"], 12500);
        assert_eq!(l.len(), 4);
        assert_eq!(l[3]["t"], 60000);
    }
}
