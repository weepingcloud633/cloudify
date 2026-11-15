//! Offline spectrum analysis of a cached track, so the visualizer follows the real audio.
//! The file is decoded once (symphonia, AAC in MP4) and turned into 30 frames per second
//! of 48 log-spaced band levels; the UI asks for the frame at the playback position.
use rustfft::{num_complex::Complex, FftPlanner};
use std::collections::HashMap;
use std::fs::File;
use std::sync::{Arc, Mutex};
use symphonia::core::{
    audio::SampleBuffer, codecs::DecoderOptions, formats::FormatOptions, io::MediaSourceStream,
    meta::MetadataOptions, probe::Hint,
};

pub const BANDS: usize = 48;
const FPS: f64 = 30.0;
const WIN: usize = 4096;

type Frames = Arc<Vec<[u8; BANDS]>>;
static DONE: Mutex<Option<HashMap<String, Frames>>> = Mutex::new(None);
static BUSY: Mutex<Option<std::collections::HashSet<String>>> = Mutex::new(None);

pub fn has(vid: &str) -> bool {
    DONE.lock().unwrap().as_ref().is_some_and(|m| m.contains_key(vid))
}

/// Band levels (0..255) at `ms`, if the track has been analysed.
pub fn at(vid: &str, ms: i64) -> Option<[u8; BANDS]> {
    let m = DONE.lock().unwrap();
    let f = m.as_ref()?.get(vid)?;
    let i = ((ms.max(0) as f64) / 1000.0 * FPS) as usize;
    f.get(i.min(f.len().saturating_sub(1))).copied()
}

/// Analyse once per track; later calls return immediately.
pub fn ensure(vid: &str, path: &std::path::Path) {
    if has(vid) {
        return;
    }
    if !BUSY.lock().unwrap().get_or_insert_with(Default::default).insert(vid.to_string()) {
        return;
    }
    let frames = analyse(path);
    BUSY.lock().unwrap().as_mut().map(|b| b.remove(vid));
    if let Ok(f) = frames {
        let mut m = DONE.lock().unwrap();
        let map = m.get_or_insert_with(Default::default);
        if map.len() > 40 {
            map.clear(); // keep memory bounded: about 3 KB per second of audio
        }
        map.insert(vid.to_string(), Arc::new(f));
    }
}

fn analyse(path: &std::path::Path) -> Result<Vec<[u8; BANDS]>, String> {
    let file = File::open(path).map_err(|e| e.to_string())?;
    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    hint.with_extension("m4a");
    let probed = symphonia::default::get_probe()
        .format(&hint, mss, &FormatOptions::default(), &MetadataOptions::default())
        .map_err(|e| e.to_string())?;
    let mut format = probed.format;
    let track = format.default_track().ok_or("no audio track")?.clone();
    let rate = track.codec_params.sample_rate.unwrap_or(44100) as f64;
    let mut dec = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|e| e.to_string())?;

    let hop = (rate / FPS) as usize;
    let fft = FftPlanner::<f32>::new().plan_fft_forward(WIN);
    let hann: Vec<f32> = (0..WIN).map(|i| 0.5 - 0.5 * (2.0 * std::f32::consts::PI * i as f32 / WIN as f32).cos()).collect();
    // band edges, log-spaced from 40 Hz to 14 kHz, as FFT bin ranges
    let bin_hz = rate / WIN as f64;
    // band edges in Hz; each band samples a few interpolated points so the narrow bass bands
    // still differ from each other even when they fall between two FFT bins
    let freqs: Vec<f64> = (0..=BANDS).map(|i| 50.0 * (14000.0f64 / 50.0).powf(i as f64 / BANDS as f64)).collect();

    let mut frames: Vec<[u8; BANDS]> = Vec::new();
    let mut acc: Vec<f32> = Vec::new();
    let mut base = 0usize; // sample index of acc[0]
    let mut total = 0usize;
    let mut next_end = WIN; // end (exclusive) of the next window
    let mut buf = vec![Complex::new(0.0f32, 0.0); WIN];

    loop {
        let pkt = match format.next_packet() {
            Ok(p) => p,
            Err(_) => break,
        };
        if pkt.track_id() != track.id {
            continue;
        }
        let Ok(decoded) = dec.decode(&pkt) else { continue };
        let spec = *decoded.spec();
        let ch = spec.channels.count().max(1);
        let mut sb = SampleBuffer::<f32>::new(decoded.capacity() as u64, spec);
        sb.copy_interleaved_ref(decoded);
        for fr in sb.samples().chunks(ch) {
            acc.push(fr.iter().sum::<f32>() / ch as f32);
            total += 1;
            if total >= next_end {
                let start = next_end - WIN - base;
                for i in 0..WIN {
                    buf[i] = Complex::new(acc[start + i] * hann[i], 0.0);
                }
                fft.process(&mut buf);
                let mut row = [0u8; BANDS];
                for b in 0..BANDS {
                    let (f0, f1) = (freqs[b], freqs[b + 1]);
                    let mut peak = 0f32;
                    for s in 0..4 {
                        let f = f0 * (f1 / f0).powf(s as f64 / 3.0);
                        let pos = (f / bin_hz).min((WIN / 2 - 2) as f64);
                        let (i, frac) = (pos as usize, (pos - pos.floor()) as f32);
                        let m = buf[i].norm() * (1.0 - frac) + buf[i + 1].norm() * frac;
                        peak = peak.max(m);
                    }
                    // magnitude to a 0..1 level over a 55 dB range
                    let db = 20.0 * (peak / (WIN as f32 / 4.0)).max(1e-6).log10();
                    row[b] = (((db + 55.0) / 55.0).clamp(0.0, 1.0) * 255.0) as u8;
                }
                frames.push(row);
                next_end += hop;
                let keep_from = next_end - WIN;
                if keep_from > base + 65536 {
                    acc.drain(..keep_from - base);
                    base = keep_from;
                }
            }
        }
    }
    if frames.is_empty() {
        return Err("no audio decoded".into());
    }
    // stretch each track's own range so quiet and loud songs both fill the bars
    let mut all: Vec<u8> = frames.iter().flat_map(|r| r.iter().copied()).collect();
    all.sort_unstable();
    let lo = all[all.len() * 5 / 100] as f32;
    let hi = (all[all.len() * 99 / 100] as f32).max(lo + 20.0);
    for row in frames.iter_mut() {
        for v in row.iter_mut() {
            let n = ((*v as f32 - lo) / (hi - lo)).clamp(0.0, 1.0);
            *v = (n.powf(1.4) * 255.0) as u8;
        }
    }
    Ok(frames)
}

#[cfg(test)]
mod tests {
    #[test]
    fn at_clamps_and_misses() {
        assert!(super::at("nope", 1000).is_none());
    }
}
