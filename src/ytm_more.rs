//! Albums, artists and album pages from YouTube Music, plus the combined search.
use serde_json::{json, Value};

const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0";
const ALBUMS: &str = "EgWKAQIYAWoMEA4QChADEAQQCRAF";
const ARTISTS: &str = "EgWKAQIgAWoMEA4QChADEAQQCRAF";

fn post(path: &str, body: Value) -> Result<Value, String> {
    ureq::post(&format!("https://music.youtube.com/youtubei/v1/{path}?prettyPrint=false"))
        .set("User-Agent", UA)
        .set("Origin", "https://music.youtube.com")
        .send_json(body)
        .map_err(|e| e.to_string())?
        .into_json()
        .map_err(|e| e.to_string())
}

fn ctx() -> Value {
    json!({"client": {"clientName": "WEB_REMIX", "clientVersion": "1.20250101.01.00", "hl": "en", "gl": "US"}})
}

fn runs_text(col: &Value) -> String {
    col["musicResponsiveListItemFlexColumnRenderer"]["text"]["runs"]
        .as_array()
        .map(|r| r.iter().filter_map(|x| x["text"].as_str()).collect::<Vec<_>>().concat())
        .unwrap_or_default()
}

fn thumb(r: &Value) -> String {
    r["thumbnail"]["musicThumbnailRenderer"]["thumbnail"]["thumbnails"]
        .as_array()
        .and_then(|a| a.last())
        .and_then(|t| t["url"].as_str())
        .unwrap_or("")
        .to_string()
}

fn collect_browse(v: &Value, out: &mut Vec<Value>) {
    match v {
        Value::Object(m) => {
            if let Some(r) = m.get("musicResponsiveListItemRenderer") {
                let id = r["navigationEndpoint"]["browseEndpoint"]["browseId"].as_str();
                let cols = r["flexColumns"].as_array();
                if let (Some(id), Some(cols)) = (id, cols) {
                    let title = runs_text(&cols[0]);
                    let sub = cols.get(1).map(runs_text).unwrap_or_default();
                    out.push(json!({"browseId": id, "title": title, "sub": sub, "thumb": thumb(r)}));
                }
            } else {
                m.values().for_each(|c| collect_browse(c, out));
            }
        }
        Value::Array(a) => a.iter().for_each(|c| collect_browse(c, out)),
        _ => {}
    }
}

fn search_kind(q: &str, params: &str) -> Vec<Value> {
    let Ok(resp) = post("search", json!({"context": ctx(), "query": q, "params": params})) else { return vec![] };
    let mut items = Vec::new();
    collect_browse(&resp, &mut items);
    items
}

/// Songs, albums and artists for one query, fetched in parallel.
pub fn search_all(q: &str) -> Value {
    let (a, b) = (q.to_string(), q.to_string());
    let albums = std::thread::spawn(move || search_kind(&a, ALBUMS));
    let artists = std::thread::spawn(move || search_kind(&b, ARTISTS));
    let songs = crate::ytm::search_songs(q).unwrap_or(Value::Array(vec![]));
    json!({
        "songs": songs,
        "albums": albums.join().unwrap_or_default().into_iter().take(10).collect::<Vec<_>>(),
        "artists": artists.join().unwrap_or_default().into_iter().take(8).collect::<Vec<_>>(),
    })
}

fn dur_secs(s: &str) -> u64 {
    s.split(':').try_fold(0u64, |t, p| p.trim().parse::<u64>().ok().map(|n| t * 60 + n)).unwrap_or(0)
}

/// The tracks of an album page. `album`, `artist` and `thumb` come from the search result.
pub fn album_tracks(browse_id: &str, album: &str, artist: &str, thumb: &str) -> Result<Value, String> {
    let resp = post("browse", json!({"context": ctx(), "browseId": browse_id}))?;
    let mut rows = Vec::new();
    fn walk(v: &Value, rows: &mut Vec<Value>) {
        match v {
            Value::Object(m) => {
                if let Some(r) = m.get("musicResponsiveListItemRenderer") {
                    rows.push(r.clone());
                } else {
                    m.values().for_each(|c| walk(c, rows));
                }
            }
            Value::Array(a) => a.iter().for_each(|c| walk(c, rows)),
            _ => {}
        }
    }
    walk(&resp, &mut rows);
    let tracks: Vec<Value> = rows
        .iter()
        .filter_map(|r| {
            let id = r["playlistItemData"]["videoId"].as_str()?;
            let title = runs_text(r["flexColumns"].as_array()?.first()?);
            let dur = r["fixedColumns"][0]["musicResponsiveListItemFixedColumnRenderer"]["text"]["runs"][0]["text"].as_str().map(dur_secs).unwrap_or(0);
            Some(json!({"id": id, "title": title, "artist": artist, "album": album, "dur": dur, "thumb": thumb}))
        })
        .collect();
    if tracks.is_empty() {
        return Err("Could not open that album".into());
    }
    Ok(Value::Array(tracks))
}

/// An artist page: name, picture, top songs and albums.
pub fn artist_page(browse_id: &str, name: &str, thumb_url: &str) -> Result<Value, String> {
    let resp = post("browse", json!({"context": ctx(), "browseId": browse_id}))?;
    let h = &resp["header"];
    let hdr = if h["musicImmersiveHeaderRenderer"].is_object() { &h["musicImmersiveHeaderRenderer"] } else { &h["musicVisualHeaderRenderer"] };
    let title = hdr["title"]["runs"][0]["text"].as_str().unwrap_or(name).to_string();
    let desc = hdr["description"]["runs"][0]["text"].as_str().unwrap_or("").chars().take(280).collect::<String>();
    let pic = hdr["thumbnail"]["musicThumbnailRenderer"]["thumbnail"]["thumbnails"].as_array().and_then(|a| a.last()).and_then(|t| t["url"].as_str()).unwrap_or(thumb_url).to_string();
    let (mut songs, mut albums): (Vec<Value>, Vec<Value>) = (Vec::new(), Vec::new());
    fn walk(v: &Value, name: &str, songs: &mut Vec<Value>, albums: &mut Vec<Value>) {
        match v {
            Value::Object(m) => {
                if let Some(r) = m.get("musicResponsiveListItemRenderer") {
                    if let (Some(id), Some(cols)) = (r["playlistItemData"]["videoId"].as_str(), r["flexColumns"].as_array()) {
                        songs.push(json!({"id": id, "title": cols.first().map(runs_text).unwrap_or_default(), "artist": name, "album": "", "dur": 0, "thumb": thumb(r)}));
                    }
                } else if let Some(r) = m.get("musicTwoRowItemRenderer") {
                    let bid = r["navigationEndpoint"]["browseEndpoint"]["browseId"].as_str().unwrap_or("");
                    if bid.starts_with("MPRE") {
                        let sub: String = r["subtitle"]["runs"].as_array().map(|a| a.iter().filter_map(|x| x["text"].as_str()).collect::<Vec<_>>().concat()).unwrap_or_default();
                        let t = r["thumbnailRenderer"]["musicThumbnailRenderer"]["thumbnail"]["thumbnails"].as_array().and_then(|a| a.last()).and_then(|t| t["url"].as_str()).unwrap_or("");
                        albums.push(json!({"browseId": bid, "title": r["title"]["runs"][0]["text"].as_str().unwrap_or(""), "sub": sub, "thumb": t}));
                    }
                } else {
                    m.values().for_each(|c| walk(c, name, songs, albums));
                }
            }
            Value::Array(a) => a.iter().for_each(|c| walk(c, name, songs, albums)),
            _ => {}
        }
    }
    walk(&resp["contents"], &title, &mut songs, &mut albums);
    if songs.is_empty() && albums.is_empty() {
        return Err("Could not open that artist".into());
    }
    songs.truncate(25);
    albums.truncate(20);
    Ok(json!({"name": title, "desc": desc, "thumb": pic, "songs": songs, "albums": albums}))
}

/// Search suggestions for what is being typed.
pub fn suggest(q: &str) -> Vec<String> {
    let Ok(resp) = post("music/get_search_suggestions", json!({"context": ctx(), "input": q})) else { return vec![] };
    let mut out = Vec::new();
    if let Some(sections) = resp["contents"].as_array() {
        for s in sections {
            for it in s["searchSuggestionsSectionRenderer"]["contents"].as_array().into_iter().flatten() {
                let runs = it["searchSuggestionRenderer"]["suggestion"]["runs"].as_array();
                if let Some(r) = runs {
                    let t: String = r.iter().filter_map(|x| x["text"].as_str()).collect::<Vec<_>>().concat();
                    if !t.is_empty() && !out.contains(&t) {
                        out.push(t);
                    }
                }
            }
        }
    }
    out.truncate(6);
    out
}

// ---- Spotify (optional, with your own developer keys) ----

fn spotify_token(id: &str, secret: &str) -> Result<String, String> {
    use base64::{engine::general_purpose::STANDARD, Engine};
    let auth = STANDARD.encode(format!("{id}:{secret}"));
    let r: Value = ureq::post("https://accounts.spotify.com/api/token")
        .set("Authorization", &format!("Basic {auth}"))
        .send_form(&[("grant_type", "client_credentials")])
        .map_err(|_| "Spotify rejected the Client ID or secret".to_string())?
        .into_json()
        .map_err(|e| e.to_string())?;
    r["access_token"].as_str().map(String::from).ok_or_else(|| "Spotify sent no token".into())
}

/// Spotify catalogue search. Songs come back without a YouTube id; the app matches one when played.
pub fn spotify_search(q: &str, id: &str, secret: &str) -> Result<Value, String> {
    let token = spotify_token(id, secret)?;
    let r: Value = ureq::get("https://api.spotify.com/v1/search")
        .set("Authorization", &format!("Bearer {token}"))
        .query("q", q)
        .query("type", "track")
        .query("limit", "10")
        .call()
        .map_err(|e| format!("Spotify search failed: {e}"))?
        .into_json()
        .map_err(|e| e.to_string())?;
    let items: Vec<Value> = r["tracks"]["items"]
        .as_array()
        .map(|a| {
            a.iter()
                .map(|t| {
                    json!({
                        "id": "", "spotify": t["id"],
                        "title": t["name"],
                        "artist": t["artists"].as_array().map(|x| x.iter().filter_map(|a| a["name"].as_str()).collect::<Vec<_>>().join(", ")).unwrap_or_default(),
                        "album": t["album"]["name"],
                        "dur": t["duration_ms"].as_u64().unwrap_or(0) / 1000,
                        "thumb": t["album"]["images"].as_array().and_then(|i| i.get(1).or(i.first())).and_then(|i| i["url"].as_str()).unwrap_or(""),
                    })
                })
                .collect()
        })
        .unwrap_or_default();
    Ok(Value::Array(items))
}

// ---- Spotify links ----

pub struct Link {
    pub kind: String,
    pub id: String,
}

pub fn parse_spotify_link(url: &str) -> Option<Link> {
    let rest = url.split("open.spotify.com/").nth(1)?;
    let mut parts = rest.split(|c| c == '/' || c == '?').filter(|p| !p.is_empty() && !p.starts_with("intl-"));
    let kind = parts.next()?.to_string();
    let id = parts.next()?.to_string();
    if !["playlist", "album", "track"].contains(&kind.as_str()) || id.len() != 22 || !id.bytes().all(|b| b.is_ascii_alphanumeric()) {
        return None;
    }
    Some(Link { kind, id })
}

fn wanted(title: &str, artist: &str, ms: u64) -> crate::library::Wanted {
    crate::library::Wanted { title: title.into(), artist: artist.split(',').next().unwrap_or("").trim().into(), dur: (ms / 1000) as u32, raw: String::new() }
}

fn api_get(token: &str, url: &str) -> Result<Value, String> {
    ureq::get(url).set("Authorization", &format!("Bearer {token}")).call().map_err(|e| format!("Spotify said no ({e}). The playlist may be private."))?.into_json().map_err(|e| e.to_string())
}

fn names(artists: &Value) -> String {
    artists.as_array().map(|a| a.iter().filter_map(|x| x["name"].as_str()).collect::<Vec<_>>().join(", ")).unwrap_or_default()
}

/// Read a public Spotify playlist, album or track: through the API when keys are set,
/// otherwise from the public embed page (first 100 songs).
pub fn spotify_link(url: &str, id: &str, secret: &str) -> Result<(String, Vec<crate::library::Wanted>), String> {
    let link = parse_spotify_link(url).ok_or("That is not a Spotify playlist, album or song link")?;
    if !id.is_empty() && !secret.is_empty() {
        let token = spotify_token(id, secret)?;
        let mut songs = Vec::new();
        let name;
        match link.kind.as_str() {
            "track" => {
                let t = api_get(&token, &format!("https://api.spotify.com/v1/tracks/{}", link.id))?;
                name = t["name"].as_str().unwrap_or("Song").to_string();
                songs.push(wanted(t["name"].as_str().unwrap_or(""), &names(&t["artists"]), t["duration_ms"].as_u64().unwrap_or(0)));
            }
            "album" => {
                let a = api_get(&token, &format!("https://api.spotify.com/v1/albums/{}", link.id))?;
                name = a["name"].as_str().unwrap_or("Album").to_string();
                for t in a["tracks"]["items"].as_array().cloned().unwrap_or_default() {
                    songs.push(wanted(t["name"].as_str().unwrap_or(""), &names(&t["artists"]), t["duration_ms"].as_u64().unwrap_or(0)));
                }
            }
            _ => {
                let p = api_get(&token, &format!("https://api.spotify.com/v1/playlists/{}?fields=name,tracks.items(track(name,duration_ms,artists(name))),tracks.next", link.id))?;
                name = p["name"].as_str().unwrap_or("Playlist").to_string();
                let mut page = p["tracks"].clone();
                loop {
                    for it in page["items"].as_array().cloned().unwrap_or_default() {
                        let t = &it["track"];
                        if t["name"].is_string() {
                            songs.push(wanted(t["name"].as_str().unwrap_or(""), &names(&t["artists"]), t["duration_ms"].as_u64().unwrap_or(0)));
                        }
                    }
                    match page["next"].as_str() {
                        Some(next) if songs.len() < 3000 => page = api_get(&token, next)?,
                        _ => break,
                    }
                }
            }
        }
        return Ok((name, songs));
    }
    // no keys: the embed page that Spotify publishes for websites
    let html = ureq::get(&format!("https://open.spotify.com/embed/{}/{}", link.kind, link.id))
        .set("User-Agent", UA)
        .call()
        .map_err(|_| "Could not read that Spotify link. Add developer keys in Settings, or use Exportify.".to_string())?
        .into_string()
        .map_err(|e| e.to_string())?;
    let start = html.find("__NEXT_DATA__").and_then(|i| html[i..].find('>').map(|j| i + j + 1)).ok_or("Spotify did not return the song list. Add developer keys in Settings, or use Exportify.")?;
    let end = html[start..].find("</script>").map(|e| start + e).ok_or("Unreadable Spotify page")?;
    let data: Value = serde_json::from_str(&html[start..end]).map_err(|e| e.to_string())?;
    let entity = &data["props"]["pageProps"]["state"]["data"]["entity"];
    let name = entity["name"].as_str().or(entity["title"].as_str()).unwrap_or("Spotify playlist").to_string();
    let songs: Vec<_> = entity["trackList"]
        .as_array()
        .map(|a| a.iter().map(|t| wanted(t["title"].as_str().unwrap_or(""), t["subtitle"].as_str().unwrap_or(""), t["duration"].as_u64().unwrap_or(0))).collect())
        .unwrap_or_default();
    if songs.is_empty() {
        return Err("Spotify did not return the song list. Add developer keys in Settings, or use Exportify.".into());
    }
    Ok((name, songs))
}

// ---- Exportify: pick up the CSV the user exports into Downloads ----

use std::sync::Mutex;
static WATCH: Mutex<Option<(std::time::SystemTime, std::collections::HashSet<String>)>> = Mutex::new(None);

pub fn watch_start() {
    *WATCH.lock().unwrap() = Some((std::time::SystemTime::now(), Default::default()));
}

/// New Spotify CSV exports in the Downloads folder since `watch_start`, each reported once.
pub fn watch_poll() -> Value {
    let mut g = WATCH.lock().unwrap();
    let Some((since, seen)) = g.as_mut() else { return json!([]) };
    let dir = std::env::var_os("USERPROFILE").map(std::path::PathBuf::from).unwrap_or_default().join("Downloads");
    let mut out = Vec::new();
    if let Ok(rd) = std::fs::read_dir(dir) {
        for e in rd.flatten() {
            let p = e.path();
            if p.extension().map_or(true, |x| !x.eq_ignore_ascii_case("csv")) {
                continue;
            }
            let Ok(m) = e.metadata() else { continue };
            if m.len() > 8 * 1024 * 1024 || m.modified().map_or(true, |t| t + std::time::Duration::from_secs(2) < *since) {
                continue;
            }
            let key = p.display().to_string();
            if seen.contains(&key) {
                continue;
            }
            let head = std::fs::read_to_string(&p).unwrap_or_default();
            let first = head.lines().next().unwrap_or("").to_lowercase();
            if first.contains("track") {
                seen.insert(key.clone());
                let songs = head.lines().count().saturating_sub(1);
                out.push(json!({"name": p.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default(), "path": key, "songs": songs}));
            }
        }
    }
    Value::Array(out)
}
