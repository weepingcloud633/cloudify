//! Daily mixes: six playlists a day, built from what the user likes and plays.
//!
//! Taste = artist weights (likes count most, then recent plays, then playlist songs). Six anchor
//! artists are drawn from the top of that list with a generator seeded by the date, so the mixes
//! are stable all day and change tomorrow. Each mix starts a YouTube Music radio from some of the
//! anchor's songs and is topped up with songs the user already knows from that artist.
use crate::{library, profiles, settings, ytm};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};

const MIXES: usize = 6;
const PER_MIX: usize = 40;

struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n.max(1) as u64) as usize
    }
    fn shuffle<T>(&mut self, v: &mut [T]) {
        for i in (1..v.len()).rev() {
            let j = self.below(i + 1);
            v.swap(i, j);
        }
    }
}

fn file() -> std::path::PathBuf {
    profiles::dir().join("mixes.json")
}

fn today() -> u64 {
    let secs = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    ((secs as i64 + crate::paths::utc_offset_secs()) / 86400).max(0) as u64
}

fn discover_file() -> std::path::PathBuf {
    profiles::dir().join("discover.json")
}

pub fn cached() -> Option<Value> {
    let v: Value = serde_json::from_slice(&std::fs::read(file()).ok()?).ok()?;
    v["mixes"].as_array().filter(|a| !a.is_empty())?;
    Some(v)
}

fn lead_artist(t: &Value) -> String {
    let a = t["artist"].as_str().unwrap_or("");
    a.split([',', '&']).next().unwrap_or(a).trim().to_string()
}


/// Reorder songs so one artist is never heard twice within `gap` songs and no artist takes more than
/// `cap` places; the first song stays first. Songs over the cap go to the end instead of being dropped.
pub fn spread(tracks: Vec<Value>, cap: usize, gap: usize) -> Vec<Value> {
    let mut rest: Vec<(String, Value)> = tracks.into_iter().map(|t| (lead_artist(&t).to_lowercase(), t)).collect();
    let mut out: Vec<(String, Value)> = Vec::new();
    let mut over: Vec<Value> = Vec::new();
    let mut count: HashMap<String, usize> = HashMap::new();
    while !rest.is_empty() {
        let recent: Vec<&String> = out.iter().rev().take(gap).map(|(a, _)| a).collect();
        // first song whose artist is not in the recent window and is under the cap; else the first under the cap
        let pick = rest
            .iter()
            .position(|(a, _)| a.is_empty() || (!recent.contains(&a) && count.get(a).copied().unwrap_or(0) < cap))
            .or_else(|| rest.iter().position(|(a, _)| a.is_empty() || count.get(a).copied().unwrap_or(0) < cap));
        match pick {
            Some(i) => {
                let (a, t) = rest.remove(i);
                *count.entry(a.clone()).or_default() += 1;
                out.push((a, t));
            }
            None => over.extend(rest.drain(..).map(|(_, t)| t)),
        }
    }
    let mut v: Vec<Value> = out.into_iter().map(|(_, t)| t).collect();
    v.extend(over);
    v
}

/// artist -> (weight, their songs the user already has)
fn taste() -> HashMap<String, (f64, Vec<Value>)> {
    let mut m: HashMap<String, (f64, Vec<Value>)> = HashMap::new();
    let mut add = |t: &Value, w: f64| {
        if t["id"].as_str().unwrap_or("").is_empty() {
            return;
        }
        let a = lead_artist(t);
        if a.is_empty() {
            return;
        }
        let e = m.entry(a).or_default();
        e.0 += w;
        if !e.1.iter().any(|x| x["id"] == t["id"]) {
            e.1.push(t.clone());
        }
    };
    // songs the person turned away from do not count towards their taste
    let (out, dis) = (library::flagged("excluded"), library::flagged("disliked"));
    let skip = |t: &Value| t["id"].as_str().is_some_and(|i| out.contains(i) || dis.contains(i));
    let lib = library::snapshot();
    for t in lib["liked"].as_array().into_iter().flatten().filter(|t| !skip(t)) {
        add(t, 3.0);
    }
    for p in lib["playlists"].as_array().into_iter().flatten() {
        for t in p["tracks"].as_array().into_iter().flatten().take(60).filter(|t| !skip(t)) {
            add(t, 1.0);
        }
    }
    let recent = settings::get()["recent"].clone();
    let n = recent.as_array().map(|a| a.len()).unwrap_or(1).max(1) as f64;
    for (i, t) in recent.as_array().into_iter().flatten().enumerate().filter(|(_, t)| !skip(t)) {
        add(t, 2.0 * (1.0 - i as f64 / n) + 0.5);
    }
    m
}

/// Today's mixes (from disk when fresh). `force` builds a different set right now.
pub fn generate(force: bool) -> Result<Value, String> {
    let day = today();
    if !force {
        if let Some(c) = cached().filter(|c| c["day"].as_u64() == Some(day)) {
            return Ok(c);
        }
    }
    let t = taste();
    let songs: usize = t.values().map(|e| e.1.len()).sum();
    if songs < 3 {
        return Err("Like a few songs and your daily mixes will appear here".into());
    }
    let salt = if force { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos() as u64).unwrap_or(1) } else { 0 };
    let mut rng = Rng(day.wrapping_mul(0x2545_F491_4F6C_DD1D) ^ salt);

    // anchors: weighted draw from the 24 strongest artists, nobody twice unless there are fewer than six
    let mut pool: Vec<(&String, &(f64, Vec<Value>))> = t.iter().collect();
    pool.sort_by(|a, b| b.1 .0.partial_cmp(&a.1 .0).unwrap().then(a.0.cmp(b.0)));
    pool.truncate(24);
    let mut anchors: Vec<usize> = Vec::new();
    let mut left: Vec<usize> = (0..pool.len()).collect();
    while anchors.len() < MIXES && !left.is_empty() {
        let total: f64 = left.iter().map(|&i| pool[i].1 .0).sum();
        let mut x = (rng.next() % 10_000) as f64 / 10_000.0 * total;
        let mut pick = left.len() - 1;
        for (k, &i) in left.iter().enumerate() {
            x -= pool[i].1 .0;
            if x <= 0.0 {
                pick = k;
                break;
            }
        }
        anchors.push(left.remove(pick));
    }
    let base = anchors.clone();
    while anchors.len() < MIXES {
        anchors.push(base[anchors.len() % base.len()]);
    }

    // one radio per mix, fetched in parallel
    let mut jobs: Vec<(String, Vec<Value>, Vec<String>)> = Vec::new();
    for &i in &anchors {
        let (name, (_, mine)) = pool[i];
        let mut mine = mine.clone();
        rng.shuffle(&mut mine);
        let seeds: Vec<String> = mine.iter().take(2).filter_map(|s| s["id"].as_str().map(String::from)).collect();
        jobs.push((name.clone(), mine, seeds));
    }
    let handles: Vec<_> = jobs
        .iter()
        .map(|(_, _, seeds)| {
            let seeds = seeds.clone();
            std::thread::spawn(move || {
                let mut out: Vec<Value> = Vec::new();
                for s in &seeds {
                    if let Ok(Value::Array(v)) = ytm::radio(s) {
                        out.extend(v);
                    }
                    if out.len() >= PER_MIX {
                        break;
                    }
                }
                out
            })
        })
        .collect();

    let mut used: HashSet<String> = HashSet::new();
    let mut mixes = Vec::new();
    let mut pool: Vec<Value> = Vec::new(); // radio songs no mix used: the raw material of Discover Weekly
    for (k, ((anchor, mine, _), h)) in jobs.into_iter().zip(handles).enumerate() {
        let disliked = library::flagged("disliked");
        let radio: Vec<Value> = h.join().unwrap_or_default().into_iter().filter(|t| !t["id"].as_str().is_some_and(|i| disliked.contains(i))).collect();
        let mut familiar = mine.into_iter().filter(|t| !t["id"].as_str().is_some_and(|i| disliked.contains(i))).take(10).collect::<Vec<_>>().into_iter();
        let mut fresh = radio.into_iter().filter(|t| t["id"].as_str().is_some_and(|i| !i.is_empty()));
        let mut seen: HashSet<String> = HashSet::new();
        let mut tracks: Vec<Value> = Vec::new();
        // every third song is one they know; the rest are discoveries not already used by an earlier mix today
        let mut n = 0;
        loop {
            if tracks.len() >= PER_MIX {
                break;
            }
            let next = if n % 3 == 0 { familiar.next().or_else(|| fresh.next()) } else { fresh.next().or_else(|| familiar.next()) };
            n += 1;
            let Some(t) = next else { break };
            let id = t["id"].as_str().unwrap_or("").to_string();
            if id.is_empty() || !seen.insert(id.clone()) || (used.contains(&id) && tracks.len() > 16) {
                continue;
            }
            tracks.push(json!({"id": id, "title": t["title"], "artist": t["artist"], "album": t["album"], "dur": t["dur"], "thumb": t["thumb"]}));
        }
        pool.extend(fresh);
        let tracks = spread(tracks, 4, 3);
        if tracks.is_empty() {
            continue;
        }
        for t in &tracks {
            used.insert(t["id"].as_str().unwrap_or("").to_string());
        }
        // who is in it: the anchor first, then whoever shows up most
        let mut count: HashMap<String, usize> = HashMap::new();
        for t in &tracks {
            let a = lead_artist(t);
            if a != anchor {
                *count.entry(a).or_default() += 1;
            }
        }
        let mut others: Vec<_> = count.into_iter().collect();
        others.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
        let mut names = vec![anchor];
        names.extend(others.into_iter().take(3).map(|x| x.0));
        mixes.push(json!({
            "id": format!("mix{}", k + 1),
            "name": format!("Daily Mix {}", k + 1),
            "desc": format!("{} and more", names.join(", ")),
            "tracks": tracks,
        }));
    }
    if mixes.is_empty() {
        return Err("Could not reach YouTube Music for your mixes".into());
    }
    // Discover Weekly: songs the person does not know yet, kept for the whole week
    let known: HashSet<String> = t.values().flat_map(|e| e.1.iter()).filter_map(|s| s["id"].as_str().map(String::from)).collect();
    let dis = library::flagged("disliked");
    let week = day / 7;
    let kept: Option<Vec<Value>> = std::fs::read(discover_file()).ok().and_then(|b| serde_json::from_slice::<Value>(&b).ok()).filter(|v| v["week"].as_u64() == Some(week) && !force).and_then(|v| v["tracks"].as_array().cloned());
    let disc: Vec<Value> = match kept {
        Some(k) => k.into_iter().filter(|s| !s["id"].as_str().is_some_and(|i| dis.contains(i))).collect(),
        None => {
            let mut seen: HashSet<String> = HashSet::new();
            let mut d: Vec<Value> = pool
                .into_iter()
                .filter(|s| s["id"].as_str().is_some_and(|i| !i.is_empty() && !known.contains(i) && !dis.contains(i) && seen.insert(i.to_string())))
                .map(|s| json!({"id": s["id"], "title": s["title"], "artist": s["artist"], "album": s["album"], "dur": s["dur"], "thumb": s["thumb"]}))
                .collect();
            rng.shuffle(&mut d);
            let mut d = spread(d, 2, 4);
            d.truncate(30);
            if d.len() >= 10 {
                let _ = std::fs::write(discover_file(), json!({"week": week, "tracks": d}).to_string());
            }
            d
        }
    };
    if disc.len() >= 10 {
        let mut artists: Vec<String> = Vec::new();
        for s in &disc {
            let a = lead_artist(s);
            if !a.is_empty() && !artists.contains(&a) {
                artists.push(a);
            }
        }
        mixes.insert(0, json!({"id": "discover", "name": "Discover Weekly", "desc": format!("New: {} and more", artists.iter().take(3).cloned().collect::<Vec<_>>().join(", ")), "tracks": disc}));
    }
    let out = json!({"day": day, "mixes": mixes});
    let tmp = file().with_extension("tmp");
    if std::fs::write(&tmp, serde_json::to_vec(&out).unwrap_or_default()).is_ok() {
        let _ = std::fs::rename(&tmp, file());
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rng_is_stable_and_shuffle_keeps_items() {
        let mut a = Rng(7);
        let mut b = Rng(7);
        assert_eq!(a.next(), b.next());
        let mut v: Vec<u32> = (0..20).collect();
        a.shuffle(&mut v);
        v.sort();
        assert_eq!(v, (0..20).collect::<Vec<_>>());
    }

    #[test]
    fn spread_separates_artists_and_keeps_first() {
        let t = |a: &str, i: u32| json!({"artist": a, "id": i.to_string()});
        let v = spread(vec![t("A", 1), t("A", 2), t("A", 3), t("B", 4), t("C", 5), t("A", 6), t("B", 7)], 2, 2);
        assert_eq!(v[0]["id"], "1");
        assert_eq!(v.len(), 7);
        for w in v.windows(2).take(4) {
            assert_ne!(lead_artist(&w[0]), lead_artist(&w[1]));
        }
        assert!(v.iter().take(5).filter(|x| lead_artist(x) == "A").count() <= 2);
    }

    #[test]
    fn lead_artist_takes_first_name() {
        assert_eq!(lead_artist(&json!({"artist": "Daft Punk, Pharrell Williams & Nile Rodgers"})), "Daft Punk");
    }
}
