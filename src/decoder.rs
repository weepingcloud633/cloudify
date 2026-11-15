//! A rodio `Source` that decodes AAC-in-MP4 with symphonia straight from the file being downloaded.
//! YouTube's MP4 is fragmented, which symphonia can read but not seek; seeking falls back to
//! re-opening the file and skipping decoded packets (a few hundred milliseconds for a whole song).
use crate::stream::{GrowingFile, Track};
use rodio::source::SeekError;
use rodio::Source;
use std::sync::Arc;
use std::time::Duration;
use symphonia::core::{
    audio::SampleBuffer,
    codecs::{Decoder, DecoderOptions},
    formats::{FormatOptions, FormatReader, SeekMode, SeekTo},
    io::{MediaSource, MediaSourceStream},
    meta::MetadataOptions,
    probe::Hint,
    units::Time,
};

impl MediaSource for GrowingFile {
    fn is_seekable(&self) -> bool {
        true
    }
    fn byte_len(&self) -> Option<u64> {
        Some(self.len())
    }
}

pub struct SymSource {
    track: Arc<Track>,
    format: Box<dyn FormatReader>,
    decoder: Box<dyn Decoder>,
    track_id: u32,
    channels: u16,
    rate: u32,
    dur: Option<Duration>,
    buf: Vec<f32>,
    idx: usize,
    sample_buf: Option<SampleBuffer<f32>>,
}

impl SymSource {
    pub fn open(track: &Arc<Track>) -> Result<Self, String> {
        let file = GrowingFile::open(track)?;
        let mss = MediaSourceStream::new(Box::new(file), Default::default());
        let mut hint = Hint::new();
        let ext = track.extension();
        hint.with_extension(if ext.is_empty() { "m4a" } else { &ext });
        let probed = symphonia::default::get_probe()
            .format(&hint, mss, &FormatOptions::default(), &MetadataOptions::default())
            .map_err(|e| format!("error: unsupported audio ({e})"))?;
        let format = probed.format;
        let t = format.default_track().ok_or("error: no audio track")?.clone();
        let decoder = symphonia::default::get_codecs()
            .make(&t.codec_params, &DecoderOptions::default())
            .map_err(|e| format!("error: cannot decode ({e})"))?;
        let rate = t.codec_params.sample_rate.unwrap_or(44100);
        let channels = t.codec_params.channels.map(|c| c.count() as u16).unwrap_or(2);
        let dur = t.codec_params.n_frames.map(|n| Duration::from_secs_f64(n as f64 / rate as f64));
        Ok(SymSource { track: track.clone(), format, decoder, track_id: t.id, channels, rate, dur, buf: Vec::new(), idx: 0, sample_buf: None })
    }

    /// Decode the next packet into `buf`; false at the end of the stream.
    fn fill(&mut self) -> bool {
        loop {
            let pkt = match self.format.next_packet() {
                Ok(p) => p,
                Err(_) => return false,
            };
            if pkt.track_id() != self.track_id {
                continue;
            }
            match self.decoder.decode(&pkt) {
                Ok(decoded) => {
                    let spec = *decoded.spec();
                    let need = decoded.capacity() as u64;
                    let sb = match &mut self.sample_buf {
                        Some(sb) if sb.capacity() as u64 >= need * spec.channels.count() as u64 => sb,
                        slot => slot.insert(SampleBuffer::<f32>::new(need, spec)),
                    };
                    sb.copy_interleaved_ref(decoded);
                    self.buf.clear();
                    self.buf.extend_from_slice(sb.samples());
                    self.idx = 0;
                    if !self.buf.is_empty() {
                        return true;
                    }
                }
                Err(symphonia::core::errors::Error::DecodeError(_)) => continue,
                Err(_) => return false,
            }
        }
    }

    fn skip_samples(&mut self, mut n: usize) {
        while n > 0 {
            if self.idx >= self.buf.len() && !self.fill() {
                return;
            }
            let take = n.min(self.buf.len() - self.idx);
            self.idx += take;
            n -= take;
        }
    }
}

impl Iterator for SymSource {
    type Item = f32;
    #[inline]
    fn next(&mut self) -> Option<f32> {
        if self.idx >= self.buf.len() && !self.fill() {
            return None;
        }
        let v = self.buf[self.idx];
        self.idx += 1;
        Some(v)
    }
}

impl Source for SymSource {
    fn current_frame_len(&self) -> Option<usize> {
        None
    }
    fn channels(&self) -> u16 {
        self.channels
    }
    fn sample_rate(&self) -> u32 {
        self.rate
    }
    fn total_duration(&self) -> Option<Duration> {
        self.dur
    }
    fn try_seek(&mut self, pos: Duration) -> Result<(), SeekError> {
        let to = SeekTo::Time { time: Time::new(pos.as_secs(), pos.subsec_nanos() as f64 / 1e9), track_id: Some(self.track_id) };
        if self.format.seek(SeekMode::Coarse, to).is_ok() {
            self.decoder.reset();
            self.buf.clear();
            self.idx = 0;
            return Ok(());
        }
        // fragmented MP4: start over and skip
        let fresh = SymSource::open(&self.track).map_err(|_| SeekError::NotSupported { underlying_source: "symphonia" })?;
        let skip = (pos.as_secs_f64() * self.rate as f64) as usize * self.channels as usize;
        *self = fresh;
        self.skip_samples(skip);
        Ok(())
    }
}
