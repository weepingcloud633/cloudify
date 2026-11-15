//! Pick a seed colour from album art: the most vivid common hue.
use std::collections::HashMap;
use std::io::Read;
use std::sync::Mutex;

type Analysis = (String, Vec<String>);
static CACHE: Mutex<Option<HashMap<String, Analysis>>> = Mutex::new(None);

/// The seed colour plus up to five swatches (most weighty hues first) for the immersive backdrop.
pub fn analyse(url: &str) -> Result<Analysis, String> {
    if let Some(c) = CACHE.lock().unwrap().as_ref().and_then(|m| m.get(url)) {
        return Ok(c.clone());
    }
    let mut buf = Vec::new();
    ureq::get(url)
        .call()
        .map_err(|e| e.to_string())?
        .into_reader()
        .take(4 * 1024 * 1024)
        .read_to_end(&mut buf)
        .map_err(|e| e.to_string())?;
    let img = image::load_from_memory(&buf).map_err(|e| e.to_string())?.thumbnail(32, 32).to_rgb8();
    // 12 hue buckets weighted by saturation * value
    let mut sum = [[0f64; 4]; 12];
    let mut avg = [0f64; 3];
    for p in img.pixels() {
        let (r, g, b) = (p[0] as f64 / 255.0, p[1] as f64 / 255.0, p[2] as f64 / 255.0);
        avg[0] += r;
        avg[1] += g;
        avg[2] += b;
        let (mx, mn) = (r.max(g).max(b), r.min(g).min(b));
        let d = mx - mn;
        if mx < 0.2 || d < 0.12 {
            continue;
        }
        let s = d / mx;
        let h = if mx == r { ((g - b) / d).rem_euclid(6.0) } else if mx == g { (b - r) / d + 2.0 } else { (r - g) / d + 4.0 };
        let w = s * mx;
        let k = ((h / 6.0 * 12.0) as usize).min(11);
        sum[k][0] += w * r;
        sum[k][1] += w * g;
        sum[k][2] += w * b;
        sum[k][3] += w;
    }
    let hex_of = |b: &[f64; 4]| format!("#{:02x}{:02x}{:02x}", (b[0] / b[3] * 255.0) as u8, (b[1] / b[3] * 255.0) as u8, (b[2] / b[3] * 255.0) as u8);
    let mut order: Vec<&[f64; 4]> = sum.iter().filter(|b| b[3] > 0.15).collect();
    order.sort_by(|a, b| b[3].partial_cmp(&a[3]).unwrap());
    let mut swatches: Vec<String> = order.iter().take(5).map(|b| hex_of(b)).collect();
    if swatches.len() < 2 {
        // a black, white or grey cover: use its own tones, light to dark, so the backdrop stays neutral
        let mut px: Vec<[f64; 3]> = img.pixels().map(|p| [p[0] as f64, p[1] as f64, p[2] as f64]).collect();
        px.sort_by(|a, b| (a[0] + a[1] + a[2]).partial_cmp(&(b[0] + b[1] + b[2])).unwrap());
        let n = px.len().max(1);
        for part in [n / 2, n / 6, n * 5 / 6, n / 3, n * 2 / 3] {
            let lo = part.saturating_sub(n / 12);
            let hi = (part + n / 12 + 1).min(n);
            let slice = &px[lo..hi.max(lo + 1).min(n)];
            let k = slice.len().max(1) as f64;
            let (r, g, b) = (slice.iter().map(|x| x[0]).sum::<f64>() / k, slice.iter().map(|x| x[1]).sum::<f64>() / k, slice.iter().map(|x| x[2]).sum::<f64>() / k);
            swatches.push(format!("#{:02x}{:02x}{:02x}", r as u8, g as u8, b as u8));
        }
        swatches.truncate(5);
    }
    let hex = match sum.iter().max_by(|a, b| a[3].partial_cmp(&b[3]).unwrap()) {
        Some(b) if b[3] > 0.5 => format!("#{:02x}{:02x}{:02x}", (b[0] / b[3] * 255.0) as u8, (b[1] / b[3] * 255.0) as u8, (b[2] / b[3] * 255.0) as u8),
        _ => {
            let n = (img.width() * img.height()) as f64;
            format!("#{:02x}{:02x}{:02x}", (avg[0] / n * 255.0) as u8, (avg[1] / n * 255.0) as u8, (avg[2] / n * 255.0) as u8)
        }
    };
    let out = (hex, swatches);
    CACHE.lock().unwrap().get_or_insert_with(Default::default).insert(url.to_string(), out.clone());
    Ok(out)
}
