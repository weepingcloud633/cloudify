//! YouTube Music search through the public innertube endpoint.
use serde_json::{json, Value};

const URL: &str = "https://music.youtube.com/youtubei/v1/search?prettyPrint=false";
const SONGS: &str = "EgWKAQIIAWoMEA4QChADEAQQCRAF";
const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0";

/// Returns `[{id,title,artist,album,dur,thumb}]` as JSON.
pub fn search_songs(q: &str) -> Result<Value, String> {
    let body = json!({
        "context": {"client": {"clientName": "WEB_REMIX", "clientVersion": "1.20250101.01.00", "hl": "en", "gl": "US"}},
        "query": q,
        "params": SONGS,
    });
    let resp: Value = ureq::post(URL)
        .set("User-Agent", UA)
        .set("Origin", "https://music.youtube.com")
        .send_json(body)
        .map_err(|e| format!("search failed: {e}"))?
        .into_json()
        .map_err(|e| format!("bad reply: {e}"))?;
    let mut items = Vec::new();
    collect(&resp, &mut items);
    Ok(Value::Array(items))
}

/// "Song radio": the songs YouTube Music queues after `vid`. Same track shape as a search.
pub fn radio(vid: &str) -> Result<Value, String> {
    let body = json!({
        "context": {"client": {"clientName": "WEB_REMIX", "clientVersion": "1.20250101.01.00", "hl": "en", "gl": "US"}},
        "videoId": vid,
        "playlistId": format!("RDAMVM{vid}"),
        "params": "wAEB",
        "isAudioOnly": true,
    });
    let resp: Value = ureq::post("https://music.youtube.com/youtubei/v1/next?prettyPrint=false")
        .set("User-Agent", UA)
        .set("Origin", "https://music.youtube.com")
        .send_json(body)
        .map_err(|e| format!("radio failed: {e}"))?
        .into_json()
        .map_err(|e| format!("bad reply: {e}"))?;
    let mut items = Vec::new();
    collect_panel(&resp, &mut items);
    if items.is_empty() {
        return Err("No radio for this song".into());
    }
    Ok(Value::Array(crate::mixes::spread(items, 3, 4)))
}

fn collect_panel(v: &Value, out: &mut Vec<Value>) {
    match v {
        Value::Object(m) => {
            if let Some(r) = m.get("playlistPanelVideoRenderer") {
                if let Some(id) = r["videoId"].as_str() {
                    let title = r["title"]["runs"][0]["text"].as_str().unwrap_or("");
                    let runs: Vec<&str> = r["longBylineText"]["runs"].as_array().map(|a| a.iter().filter_map(|x| x["text"].as_str()).collect()).unwrap_or_default();
                    let mut groups = vec![String::new()];
                    for t in runs {
                        if t.trim() == "•" {
                            groups.push(String::new());
                        } else {
                            groups.last_mut().unwrap().push_str(t);
                        }
                    }
                    let dur = r["lengthText"]["runs"][0]["text"].as_str().and_then(parse_dur).unwrap_or(0);
                    let thumb = r["thumbnail"]["thumbnails"].as_array().and_then(|a| a.last()).and_then(|t| t["url"].as_str()).unwrap_or("");
                    out.push(json!({
                        "id": id, "title": title, "artist": groups[0], "album": groups.get(1).cloned().unwrap_or_default(),
                        "dur": dur, "thumb": thumb,
                    }));
                }
            } else {
                m.values().for_each(|c| collect_panel(c, out));
            }
        }
        Value::Array(a) => a.iter().for_each(|c| collect_panel(c, out)),
        _ => {}
    }
}

fn collect(v: &Value, out: &mut Vec<Value>) {
    match v {
        Value::Object(m) => {
            if let Some(r) = m.get("musicResponsiveListItemRenderer") {
                if let Some(t) = parse_item(r) {
                    out.push(t);
                }
            } else {
                for c in m.values() {
                    collect(c, out);
                }
            }
        }
        Value::Array(a) => a.iter().for_each(|c| collect(c, out)),
        _ => {}
    }
}

fn runs(col: &Value) -> Vec<String> {
    col["musicResponsiveListItemFlexColumnRenderer"]["text"]["runs"]
        .as_array()
        .map(|r| r.iter().filter_map(|x| x["text"].as_str().map(String::from)).collect())
        .unwrap_or_default()
}

fn parse_dur(s: &str) -> Option<u32> {
    let mut total = 0u32;
    for part in s.split(':') {
        total = total * 60 + part.trim().parse::<u32>().ok()?;
    }
    Some(total)
}

fn parse_item(r: &Value) -> Option<Value> {
    let id = r["playlistItemData"]["videoId"].as_str()?;
    let cols = r["flexColumns"].as_array()?;
    let title = runs(cols.first()?).concat();
    let meta = runs(cols.get(1)?);
    let mut groups: Vec<String> = Vec::new();
    let mut cur = String::new();
    for t in meta {
        if t.trim() == "•" {
            groups.push(std::mem::take(&mut cur));
        } else {
            cur.push_str(&t);
        }
    }
    groups.push(cur);
    if matches!(groups.first().map(String::as_str), Some("Song") | Some("Video")) {
        groups.remove(0);
    }
    let dur = groups.last().and_then(|g| parse_dur(g)).unwrap_or(0);
    let artist = groups.first().cloned().unwrap_or_default();
    let album = if groups.len() >= 3 { groups[1].clone() } else { String::new() };
    let thumb = r["thumbnail"]["musicThumbnailRenderer"]["thumbnail"]["thumbnails"]
        .as_array()
        .and_then(|a| a.last())
        .and_then(|t| t["url"].as_str())
        .unwrap_or("");
    Some(json!({"id": id, "title": title, "artist": artist, "album": album, "dur": dur, "thumb": thumb}))
}
