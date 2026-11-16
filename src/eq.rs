//! Six-band equalizer (Swiftify's bands: 60, 150, 400, 1k, 2.4k and 15k Hz, peaking filters,
//! Q 0.9, plus or minus 12 dB) applied to the decoded samples just before the output.
use rodio::Source;
use std::sync::atomic::{AtomicU32, Ordering};
use std::time::Duration;

pub const BANDS: usize = 6;
const FREQ: [f32; BANDS] = [60.0, 150.0, 400.0, 1_000.0, 2_400.0, 15_000.0];
const Q: f32 = 0.9;
const MAX_DB: f32 = 12.0;

static GAINS: [AtomicU32; BANDS] = [const { AtomicU32::new(0) }; BANDS];
static GEN: AtomicU32 = AtomicU32::new(1);
static PRE: AtomicU32 = AtomicU32::new(0); // preamp in dB, as f32 bits

/// Overall gain before the bands, in dB (plus or minus 12).
pub fn set_preamp(db: f32) {
    PRE.store(if db.is_finite() { db.clamp(-12.0, 12.0) } else { 0.0 }.to_bits(), Ordering::Relaxed);
    GEN.fetch_add(1, Ordering::Release);
}

/// Set the six gains in dB (clamped to plus or minus 12); the playing track follows at once.
pub fn set(gains: &[f32]) {
    for (i, slot) in GAINS.iter().enumerate() {
        let g = gains.get(i).copied().unwrap_or(0.0);
        let g = if g.is_finite() { g.clamp(-MAX_DB, MAX_DB) } else { 0.0 };
        slot.store(g.to_bits(), Ordering::Relaxed);
    }
    GEN.fetch_add(1, Ordering::Release);
}

fn gains() -> [f32; BANDS] {
    std::array::from_fn(|i| f32::from_bits(GAINS[i].load(Ordering::Relaxed)))
}

/// RBJ cookbook peaking filter, normalised: [b0, b1, b2, a1, a2].
fn peaking(freq: f32, sr: f32, db: f32) -> [f32; 5] {
    let a = 10f32.powf(db / 40.0);
    let w = 2.0 * std::f32::consts::PI * (freq / sr).min(0.49);
    let (s, c) = w.sin_cos();
    let alpha = s / (2.0 * Q);
    let a0 = 1.0 + alpha / a;
    [(1.0 + alpha * a) / a0, -2.0 * c / a0, (1.0 - alpha * a) / a0, -2.0 * c / a0, (1.0 - alpha / a) / a0]
}

pub struct Eq<S: Source<Item = f32>> {
    src: S,
    channels: usize,
    rate: f32,
    seen: u32,
    coef: [[f32; 5]; BANDS],
    // per channel, per band: x1, x2, y1, y2
    state: Vec<[[f32; 4]; BANDS]>,
    headroom: f32,
    active: bool,
    pos: usize,
}

impl<S: Source<Item = f32>> Eq<S> {
    pub fn new(src: S) -> Self {
        let channels = src.channels().max(1) as usize;
        let rate = src.sample_rate().max(8000) as f32;
        let mut e = Eq { src, channels, rate, seen: 0, coef: [[0.0; 5]; BANDS], state: vec![[[0.0; 4]; BANDS]; channels], headroom: 1.0, active: false, pos: 0 };
        e.refresh();
        e
    }

    fn refresh(&mut self) {
        self.seen = GEN.load(Ordering::Acquire);
        let g = gains();
        let pre = f32::from_bits(PRE.load(Ordering::Relaxed));
        self.active = pre.abs() > 0.01 || g.iter().any(|x| x.abs() > 0.01);
        for i in 0..BANDS {
            self.coef[i] = peaking(FREQ[i], self.rate, g[i]);
        }
        // leave room for the boost so loud tracks do not clip
        let top = g.iter().cloned().fold(0.0f32, f32::max);
        self.headroom = 10f32.powf((pre - top * 0.6) / 20.0);
    }
}

impl<S: Source<Item = f32>> Iterator for Eq<S> {
    type Item = f32;
    fn next(&mut self) -> Option<f32> {
        let mut x = self.src.next()?;
        if self.pos & 255 == 0 && self.seen != GEN.load(Ordering::Acquire) {
            self.refresh();
        }
        let ch = self.pos % self.channels;
        self.pos = self.pos.wrapping_add(1);
        if self.active {
            let st = &mut self.state[ch];
            for b in 0..BANDS {
                let c = &self.coef[b];
                let s = &mut st[b];
                let y = c[0] * x + c[1] * s[0] + c[2] * s[1] - c[3] * s[2] - c[4] * s[3];
                s[1] = s[0];
                s[0] = x;
                s[3] = s[2];
                s[2] = y;
                x = y;
            }
            x = (x * self.headroom).clamp(-1.0, 1.0);
        }
        Some(x)
    }
}

impl<S: Source<Item = f32>> Source for Eq<S> {
    fn current_frame_len(&self) -> Option<usize> {
        self.src.current_frame_len()
    }
    fn channels(&self) -> u16 {
        self.src.channels()
    }
    fn sample_rate(&self) -> u32 {
        self.src.sample_rate()
    }
    fn total_duration(&self) -> Option<Duration> {
        self.src.total_duration()
    }
    fn try_seek(&mut self, pos: Duration) -> Result<(), rodio::source::SeekError> {
        self.state.iter_mut().for_each(|s| *s = [[0.0; 4]; BANDS]);
        self.pos = 0;
        self.src.try_seek(pos)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flat_filter_is_identity() {
        let c = peaking(1000.0, 44100.0, 0.0);
        assert!((c[0] - 1.0).abs() < 1e-5 && (c[1] - c[3]).abs() < 1e-5 && (c[2] - c[4]).abs() < 1e-5);
    }

    #[test]
    fn boost_raises_gain_at_centre() {
        // |H| at the centre frequency of a +6 dB peak is about 2x
        let c = peaking(1000.0, 48000.0, 6.0);
        let w = 2.0 * std::f32::consts::PI * 1000.0 / 48000.0;
        let (re, im) = (|a: f32, b: f32, c2: f32| (a + b * w.cos() + c2 * (2.0 * w).cos(), -(b * w.sin() + c2 * (2.0 * w).sin())))(c[0], c[1], c[2]);
        let (dr, di) = (1.0 + c[3] * w.cos() + c[4] * (2.0 * w).cos(), -(c[3] * w.sin() + c[4] * (2.0 * w).sin()));
        let gain = ((re * re + im * im) / (dr * dr + di * di)).sqrt();
        assert!((gain - 2.0).abs() < 0.05, "gain {gain}");
    }
}
