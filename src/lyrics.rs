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

/// "Song (feat. X) - Remastered 2011 [Official Video]" -> "Song"
fn clean_title(t: &str) -> String {
    let mut s = t.to_string();
    for (open, close) in [('(', ')'), ('[', ']')] {
        while let (Some(a), Some(b)) = (s.find(open), s.find(close)) {
            if b < a {
                break;
            }
            s.replace_range(a..=b, "");
        }
    }
    for sep in [" - ", " – ", " feat.", " ft.", " featuring "] {
        if let Some(i) = s.find(sep) {
            s.truncate(i);
        }
    }
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// The best search hit: synced beats plain, and the length should be close to the song's.
fn best_hit(list: &[Value], dur: u64) -> Option<Value> {
    let mut best: Option<(i64, &Value)> = None;
    for r in list {
        let d = r["duration"].as_f64().unwrap_or(0.0) as i64;
        let off = if dur == 0 || d == 0 { 0 } else { (d - dur as i64).abs() };
        let score = (if r["syncedLyrics"].as_str().is_some_and(|s| !s.trim().is_empty()) { 0 } else { 100 }) + off;
        if best.map_or(true, |b| score < b.0) {
            best = Some((score, r));
        }
    }
    best.filter(|b| b.0 < 120).and_then(|b| from_record(b.1))
}

pub fn fetch(vid: &str, title: &str, artist: &str, album: &str, dur: u64) -> Value {
    let cache = paths::dir("cache/lyrics").join(format!("{vid}.json"));
    if let Some(v) = std::fs::read(&cache).ok().and_then(|b| serde_json::from_slice::<Value>(&b).ok()) {
        return v;
    }
    let who = artist.split([',', '&']).next().unwrap_or(artist).trim().to_string();
    let clean = clean_title(title);
    let exact = |name: &str| format!("https://lrclib.net/api/get?track_name={}&artist_name={}&album_name={}&duration={}", enc(name), enc(&who), enc(album), dur);
    let mut found = get(&exact(title)).and_then(|r| from_record(&r));
    if found.is_none() && clean != title && !clean.is_empty() {
        found = get(&exact(&clean)).and_then(|r| from_record(&r));
    }
    // searches, widest last; a synced hit anywhere beats plain text
    let name = if clean.is_empty() { title.to_string() } else { clean };
    for q in [
        format!("https://lrclib.net/api/search?track_name={}&artist_name={}", enc(&name), enc(&who)),
        format!("https://lrclib.net/api/search?q={}", enc(&format!("{who} {name}"))),
    ] {
        if found.as_ref().is_some_and(|f| f["synced"] == true) {
            break;
        }
        if let Some(Value::Array(list)) = get(&q) {
            if let Some(hit) = best_hit(&list, dur) {
                if found.is_none() || hit["synced"] == true {
                    found = Some(hit);
                }
            }
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
    fn titles_lose_decorations() {
        assert_eq!(clean_title("Get Lucky (feat. Pharrell) [Official Video]"), "Get Lucky");
        assert_eq!(clean_title("Song - Remastered 2011"), "Song");
        assert_eq!(clean_title("Plain"), "Plain");
    }

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
