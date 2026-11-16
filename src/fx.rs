//! Sound shaping that sits between the decoder and the equalizer: playback speed and pitch (WSOLA
//! time stretching plus resampling), loudness normalisation, and a frame counter for the position.
use rodio::source::SeekError;
use rodio::Source;
use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

static SPEED: AtomicU32 = AtomicU32::new(0x3f80_0000); // 1.0
static PITCH: AtomicU32 = AtomicU32::new(0); // semitones, 0.0
static NORM: AtomicBool = AtomicBool::new(false);
static GEN: AtomicU32 = AtomicU32::new(1);

pub fn set_speed(x: f32) {
    SPEED.store(if x.is_finite() { x.clamp(0.5, 2.0) } else { 1.0 }.to_bits(), Ordering::Relaxed);
    GEN.fetch_add(1, Ordering::Release);
}

pub fn set_pitch(semitones: f32) {
    PITCH.store(if semitones.is_finite() { semitones.clamp(-12.0, 12.0) } else { 0.0 }.to_bits(), Ordering::Relaxed);
    GEN.fetch_add(1, Ordering::Release);
}

pub fn set_normalize(on: bool) {
    NORM.store(on, Ordering::Relaxed);
}

// ---------------------------------------------------------------- counting

/// Counts the frames that have been read, so the position does not depend on the sink.
pub struct Counted<S: Source<Item = f32>> {
    src: S,
    frames: Arc<AtomicU64>,
    ch: u64,
    n: u64,
}

impl<S: Source<Item = f32>> Counted<S> {
    pub fn new(src: S, frames: Arc<AtomicU64>) -> Self {
        let ch = src.channels().max(1) as u64;
        Counted { src, frames, ch, n: 0 }
    }
}

impl<S: Source<Item = f32>> Iterator for Counted<S> {
    type Item = f32;
    #[inline]
    fn next(&mut self) -> Option<f32> {
        let x = self.src.next()?;
        self.n += 1;
        if self.n % 512 == 0 {
            self.frames.store(self.n / self.ch, Ordering::Relaxed);
        }
        Some(x)
    }
}

impl<S: Source<Item = f32>> Source for Counted<S> {
    fn current_frame_len(&self) -> Option<usize> {
        None
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
    fn try_seek(&mut self, pos: Duration) -> Result<(), SeekError> {
        self.src.try_seek(pos)?;
        self.n = (pos.as_secs_f64() * self.src.sample_rate() as f64) as u64 * self.ch;
        self.frames.store(self.n / self.ch, Ordering::Relaxed);
        Ok(())
    }
}

// ---------------------------------------------------------------- speed and pitch

const N: usize = 2048; // window, in frames
const HS: usize = N / 2; // synthesis hop
const DELTA: usize = 160; // how far the best overlap is looked for

pub struct Stretch<S: Source<Item = f32>> {
    src: S,
    ch: usize,
    over: Option<(f32, f32)>, // fixed (speed, semitones), for tests
    seen: u32,
    active: bool,
    tempo: f64, // WSOLA rate: how much faster the source is walked than the output is made
    rho: f64,   // resampling ratio: pitch
    inb: Vec<f32>,
    in_base: usize,
    eof: bool,
    ideal: f64,
    prev: Option<usize>,
    tail: Vec<f32>,
    stretched: VecDeque<f32>,
    rpos: f64,
    cur: Vec<f32>,
    ci: usize,
    win: Vec<f32>,
    done: bool,
}

impl<S: Source<Item = f32>> Stretch<S> {
    pub fn new(src: S) -> Self {
        Self::build(src, None)
    }

    #[cfg(test)]
    fn with(src: S, speed: f32, semitones: f32) -> Self {
        Self::build(src, Some((speed, semitones)))
    }

    fn build(src: S, over: Option<(f32, f32)>) -> Self {
        let ch = src.channels().max(1) as usize;
        let win = (0..N).map(|i| 0.5 - 0.5 * (2.0 * std::f32::consts::PI * i as f32 / N as f32).cos()).collect();
        let mut s = Stretch { src, ch, over, seen: 0, active: false, tempo: 1.0, rho: 1.0, inb: Vec::new(), in_base: 0, eof: false, ideal: 0.0, prev: None, tail: vec![0.0; HS * ch], stretched: VecDeque::new(), rpos: 0.0, cur: vec![0.0; ch], ci: ch, win, done: false };
        s.refresh();
        s
    }

    fn params(&self) -> (f32, f32) {
        self.over.unwrap_or_else(|| (f32::from_bits(SPEED.load(Ordering::Relaxed)), f32::from_bits(PITCH.load(Ordering::Relaxed))))
    }

    fn reset(&mut self) {
        self.inb.clear();
        self.in_base = 0;
        self.eof = false;
        self.ideal = 0.0;
        self.prev = None;
        self.tail.iter_mut().for_each(|x| *x = 0.0);
        self.stretched.clear();
        self.rpos = 0.0;
        self.ci = self.ch;
        self.done = false;
    }

    fn refresh(&mut self) {
        self.seen = GEN.load(Ordering::Acquire);
        let (speed, semis) = self.params();
        let pitch = 2f64.powf(semis as f64 / 12.0);
        let was = self.active;
        self.active = (speed - 1.0).abs() > 0.005 || semis.abs() > 0.01;
        self.rho = pitch;
        self.tempo = speed as f64 / pitch;
        if self.active && !was {
            self.reset();
        }
    }

    fn frames_in(&self) -> usize {
        self.inb.len() / self.ch
    }

    fn pull(&mut self, until: usize) {
        while !self.eof && self.in_base + self.frames_in() < until {
            for _ in 0..self.ch {
                match self.src.next() {
                    Some(x) => self.inb.push(x),
                    None => {
                        self.eof = true;
                        break;
                    }
                }
            }
            if self.inb.len() % self.ch != 0 {
                let pad = self.ch - self.inb.len() % self.ch;
                self.inb.extend(std::iter::repeat(0.0).take(pad));
            }
        }
    }

    fn mono(&self, frame: usize) -> f32 {
        let i = frame.saturating_sub(self.in_base);
        if i >= self.frames_in() {
            return 0.0;
        }
        (0..self.ch).map(|c| self.inb[i * self.ch + c]).sum::<f32>() / self.ch as f32
    }

    /// Make the next window of stretched audio. False when the source has run out.
    fn produce(&mut self) -> bool {
        if self.done {
            return false;
        }
        let ideal = self.ideal.round().max(0.0) as usize;
        self.pull(ideal + DELTA + N + HS);
        let total = self.in_base + self.frames_in();
        if ideal >= total && self.eof {
            // flush what is left of the overlap
            let tail = std::mem::replace(&mut self.tail, vec![0.0; HS * self.ch]);
            self.stretched.extend(tail);
            self.done = true;
            return true;
        }
        let start = match self.prev {
            None => ideal,
            Some(p) => {
                // the continuation of the previous window, and the start that matches it best
                let nat: Vec<f32> = (0..HS).step_by(2).map(|k| self.mono(p + HS + k)).collect();
                let lo = ideal.saturating_sub(DELTA).max(self.in_base);
                let (mut best, mut best_c) = (ideal, f32::MIN);
                for s in lo..=ideal + DELTA {
                    let c: f32 = nat.iter().enumerate().map(|(i, v)| v * self.mono(s + i * 2)).sum();
                    if c > best_c {
                        best_c = c;
                        best = s;
                    }
                }
                best
            }
        };
        let mut out = vec![0.0f32; HS * self.ch];
        for i in 0..N {
            let f = start + i;
            let w = self.win[i];
            for c in 0..self.ch {
                let idx = f.saturating_sub(self.in_base) * self.ch + c;
                let v = if f >= self.in_base && idx < self.inb.len() { self.inb[idx] * w } else { 0.0 };
                if i < HS {
                    out[i * self.ch + c] = self.tail[i * self.ch + c] + v;
                } else {
                    self.tail[(i - HS) * self.ch + c] = v;
                }
            }
        }
        self.stretched.extend(out);
        self.prev = Some(start);
        self.ideal += HS as f64 * self.tempo;
        // forget input nobody needs any more
        let keep_from = (start + HS).min((self.ideal.round().max(0.0) as usize).saturating_sub(DELTA));
        if keep_from > self.in_base + N {
            let drop = (keep_from - self.in_base).min(self.frames_in());
            self.inb.drain(..drop * self.ch);
            self.in_base += drop;
        }
        true
    }

    /// The next output frame into `cur`; false at the end.
    fn frame(&mut self) -> bool {
        while self.stretched.len() / self.ch < self.rpos as usize + 2 {
            if !self.produce() {
                break;
            }
        }
        let i = self.rpos as usize;
        let avail = self.stretched.len() / self.ch;
        if i >= avail {
            return false;
        }
        let f = (self.rpos - i as f64) as f32;
        for c in 0..self.ch {
            let a = self.stretched[i * self.ch + c];
            let b = if i + 1 < avail { self.stretched[(i + 1) * self.ch + c] } else { a };
            self.cur[c] = a + (b - a) * f;
        }
        self.rpos += self.rho;
        let drop = self.rpos as usize;
        if drop > 0 {
            self.stretched.drain(..(drop * self.ch).min(self.stretched.len()));
            self.rpos -= drop as f64;
        }
        true
    }
}

impl<S: Source<Item = f32>> Iterator for Stretch<S> {
    type Item = f32;
    fn next(&mut self) -> Option<f32> {
        if self.seen != GEN.load(Ordering::Acquire) && self.over.is_none() {
            let was = self.active;
            self.refresh();
            if was && !self.active {
                // leave the shaped path: what is buffered is dropped
                self.reset();
            }
        }
        if !self.active {
            return self.src.next();
        }
        if self.ci >= self.ch {
            if !self.frame() {
                return None;
            }
            self.ci = 0;
        }
        let v = self.cur[self.ci];
        self.ci += 1;
        Some(v)
    }
}

impl<S: Source<Item = f32>> Source for Stretch<S> {
    fn current_frame_len(&self) -> Option<usize> {
        None
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
    fn try_seek(&mut self, pos: Duration) -> Result<(), SeekError> {
        self.src.try_seek(pos)?;
        self.reset();
        Ok(())
    }
}

// ---------------------------------------------------------------- loudness

/// A slow automatic gain that aims every song at about the same loudness, with a soft limiter.
pub struct Norm<S: Source<Item = f32>> {
    src: S,
    ms: f32,
    gain: f32,
    alpha: f32,
    slew: f32,
}

impl<S: Source<Item = f32>> Norm<S> {
    pub fn new(src: S) -> Self {
        let per_s = (src.sample_rate().max(8000) as f32) * src.channels().max(1) as f32;
        Norm { src, ms: 0.02, gain: 1.0, alpha: 1.0 / (per_s * 2.0), slew: 1.0 / (per_s * 1.2) }
    }
}

impl<S: Source<Item = f32>> Iterator for Norm<S> {
    type Item = f32;
    #[inline]
    fn next(&mut self) -> Option<f32> {
        let x = self.src.next()?;
        if !NORM.load(Ordering::Relaxed) {
            if self.gain != 1.0 {
                self.gain += (1.0 - self.gain) * self.slew * 4.0;
                if (self.gain - 1.0).abs() < 0.001 {
                    self.gain = 1.0;
                }
            } else {
                return Some(x);
            }
        } else {
            self.ms += (x * x - self.ms) * self.alpha;
            if self.ms > 1e-6 {
                let target = (0.11 / self.ms.sqrt()).clamp(0.35, 3.0);
                self.gain += (target - self.gain) * self.slew;
            }
        }
        let y = x * self.gain;
        Some(if y.abs() > 0.9 { y.signum() * (0.9 + (y.abs() - 0.9).tanh() * 0.1) } else { y })
    }
}

impl<S: Source<Item = f32>> Source for Norm<S> {
    fn current_frame_len(&self) -> Option<usize> {
        None
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
    fn try_seek(&mut self, pos: Duration) -> Result<(), SeekError> {
        self.src.try_seek(pos)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Sine {
        i: usize,
        len: usize,
        freq: f32,
    }
    impl Iterator for Sine {
        type Item = f32;
        fn next(&mut self) -> Option<f32> {
            if self.i >= self.len {
                return None;
            }
            let v = (2.0 * std::f32::consts::PI * self.freq * self.i as f32 / 44100.0).sin() * 0.5;
            self.i += 1;
            Some(v)
        }
    }
    impl Source for Sine {
        fn current_frame_len(&self) -> Option<usize> {
            None
        }
        fn channels(&self) -> u16 {
            1
        }
        fn sample_rate(&self) -> u32 {
            44100
        }
        fn total_duration(&self) -> Option<Duration> {
            None
        }
    }

    fn crossings(v: &[f32]) -> usize {
        v.windows(2).filter(|w| w[0] <= 0.0 && w[1] > 0.0).count()
    }

    #[test]
    fn faster_is_shorter_and_keeps_pitch() {
        let out: Vec<f32> = Stretch::with(Sine { i: 0, len: 88200, freq: 440.0 }, 1.5, 0.0).collect();
        let secs = out.len() as f32 / 44100.0;
        assert!((secs - 2.0 / 1.5).abs() < 0.12, "length {secs}");
        let hz = crossings(&out) as f32 / secs;
        assert!((hz - 440.0).abs() < 25.0, "pitch {hz}");
    }

    #[test]
    fn pitch_up_an_octave_keeps_length() {
        let out: Vec<f32> = Stretch::with(Sine { i: 0, len: 88200, freq: 440.0 }, 1.0, 12.0).collect();
        let secs = out.len() as f32 / 44100.0;
        assert!((secs - 2.0).abs() < 0.12, "length {secs}");
        let hz = crossings(&out) as f32 / secs;
        assert!((hz - 880.0).abs() < 40.0, "pitch {hz}");
    }

    #[test]
    fn untouched_audio_passes_through() {
        let a: Vec<f32> = Stretch::with(Sine { i: 0, len: 5000, freq: 300.0 }, 1.0, 0.0).collect();
        assert_eq!(a.len(), 5000);
    }
}
