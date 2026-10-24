// SystemDesk: echo cancellation and noise suppression for the microphone of a voice call.
//
// What the microphone hears is the person talking, the room, and what this computer plays on its own speakers (the voice of the other side, and the
// sound of the controlled computer when a controller listens to it). Sent as it is, the other side hears its own voice come back after a moment, and the
// noise of the room with it. So the microphone goes through two steps before it is encoded:
//   1. echo cancellation (the echo canceller of WebRTC, `aec3`), told what this process plays, learns how that sound comes back into the microphone
//      and takes it out;
//   2. noise suppression (RNNoise, `nnnoiseless`), which keeps the voice and removes steady and sudden noise (fans, keys, clicks).
// `RenderFeed` is the ear on the playback side: the player of the audio hands over what it gives to the speakers. `VoiceDsp` runs on the thread that
// encodes the microphone and takes that sound from every player of this process. Both live in one process on both sides of a call (the controlled
// computer plays the voice of the controller; the controller plays the sound and the voice of the controlled computer).
//
// Only where the microphone is captured with cpal (Windows, macOS). Elsewhere the types are there and do nothing.

/// Settings > Audio: "Cancel echo and noise in voice calls" (option `enable-voice-processing`, on unless it is `N`).
#[cfg(any(target_os = "windows", target_os = "macos"))]
pub fn enabled() -> bool {
    hbb_common::config::Config::get_option("enable-voice-processing") != "N"
}

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
pub fn enabled() -> bool {
    false
}

#[cfg(any(target_os = "windows", target_os = "macos"))]
pub use real::{render_wanted, RenderFeed, VoiceDsp};

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
pub use stub::{render_wanted, RenderFeed, VoiceDsp};

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
mod stub {
    pub fn render_wanted() -> bool {
        false
    }

    pub struct RenderFeed;

    impl RenderFeed {
        pub fn new(_sample_rate: u32, _channels: usize) -> Self {
            Self
        }

        pub fn push(&mut self, _interleaved: &[f32]) {}
    }

    pub struct VoiceDsp;

    impl VoiceDsp {
        pub fn new() -> Option<Self> {
            None
        }

        pub fn process(&mut self, _block: &mut [f32], _channels: usize) {}
    }
}

#[cfg(any(target_os = "windows", target_os = "macos"))]
mod real {
    use aec3::{
        nodes::audio::AudioFormat,
        pipelines::linear::{self, LinearPipeline},
    };
    use hbb_common::log;
    use nnnoiseless::DenoiseState;
    use std::{
        collections::VecDeque,
        sync::{
            atomic::{AtomicUsize, Ordering},
            Arc, Mutex, Weak,
        },
    };

    pub const SAMPLE_RATE: u32 = 48_000;
    /// 10 ms at 48 kHz, one channel: the size of a block of the echo canceller and of the noise suppressor.
    pub const FRAME: usize = 480;
    // a player starts to count once it has this much to hand over (10 ms), so the sound that is taken is there when it is asked for
    const PRIME_SAMPLES: usize = FRAME;
    // more than this (30 ms above the prime) is old: skip ahead, so the reference does not drift behind what is really played
    const MAX_LAG_SAMPLES: usize = FRAME * 3;
    // a player that is not asked (nobody encodes) must not grow
    const MAX_QUEUED_SAMPLES: usize = SAMPLE_RATE as usize;
    // the noise suppressor works on the scale of 16 bit samples
    const S16_SCALE: f32 = 32768.0;

    // how many microphones are being processed in this process: the players only hand over their sound while one is
    static ACTIVE: AtomicUsize = AtomicUsize::new(0);

    pub fn render_wanted() -> bool {
        ACTIVE.load(Ordering::Relaxed) > 0
    }

    #[derive(Default)]
    struct QueueState {
        samples: VecDeque<f32>,
        primed: bool,
    }

    #[derive(Default)]
    struct RenderQueue {
        state: Mutex<QueueState>,
    }

    impl RenderQueue {
        // Called by the thread of the player (the audio callback): never waits for the thread that encodes.
        fn push(&self, mono_48k: &[f32]) {
            let Ok(mut state) = self.state.try_lock() else {
                return;
            };
            state.samples.extend(mono_48k.iter().copied());
            let over = state.samples.len().saturating_sub(MAX_QUEUED_SAMPLES);
            if over > 0 {
                state.samples.drain(..over);
            }
        }

        // Adds the next 10 ms of this player to `out`; silence when it has nothing (yet).
        fn add_next_frame_to(&self, out: &mut [f32]) {
            let Ok(mut state) = self.state.lock() else {
                return;
            };
            let have = state.samples.len();
            if !state.primed {
                if have < PRIME_SAMPLES + FRAME {
                    return;
                }
                state.primed = true;
            }
            if have < FRAME {
                state.primed = false;
                return;
            }
            if have > PRIME_SAMPLES + MAX_LAG_SAMPLES {
                let skip = have - PRIME_SAMPLES;
                state.samples.drain(..skip);
            }
            for (o, s) in out.iter_mut().zip(state.samples.drain(..FRAME)) {
                *o += s;
            }
        }
    }

    // every player of this process, as the encoder of the microphone finds them
    static QUEUES: Mutex<Vec<Weak<RenderQueue>>> = Mutex::new(Vec::new());

    /// The ear on the playback side. One per audio output stream; `push` is given what the stream gives to the speakers.
    pub struct RenderFeed {
        queue: Arc<RenderQueue>,
        channels: usize,
        // input samples per output sample (the speakers may not run at 48 kHz)
        ratio: f64,
        // where the next output sample lies, in input samples from the start of the next block
        position: f64,
        mono: Vec<f32>,
        out: Vec<f32>,
    }

    impl RenderFeed {
        pub fn new(sample_rate: u32, channels: usize) -> Self {
            let queue = Arc::new(RenderQueue::default());
            if let Ok(mut queues) = QUEUES.lock() {
                queues.push(Arc::downgrade(&queue));
            }
            Self {
                queue,
                channels: channels.max(1),
                ratio: sample_rate.max(1) as f64 / SAMPLE_RATE as f64,
                position: 0.0,
                mono: Vec::new(),
                out: Vec::new(),
            }
        }

        pub fn push(&mut self, interleaved: &[f32]) {
            if interleaved.is_empty() || !render_wanted() {
                return;
            }
            self.mono.clear();
            let channels = self.channels as f32;
            self.mono.extend(
                interleaved
                    .chunks_exact(self.channels)
                    .map(|frame| frame.iter().sum::<f32>() / channels),
            );
            if (self.ratio - 1.0).abs() < 1e-9 {
                self.queue.push(&self.mono);
                return;
            }
            // linear interpolation between the two input samples around each output sample
            self.out.clear();
            let n = self.mono.len() as f64;
            while self.position < n {
                let i = self.position.floor();
                let frac = (self.position - i) as f32;
                let i = i as usize;
                let a = self.mono[i];
                let b = self.mono.get(i + 1).copied().unwrap_or(a);
                self.out.push(a + (b - a) * frac);
                self.position += self.ratio;
            }
            self.position -= n;
            self.queue.push(&self.out);
        }
    }

    /// Echo cancellation and noise suppression of one microphone, in 10 ms blocks at 48 kHz.
    pub struct VoiceDsp {
        pipeline: LinearPipeline,
        denoise: Box<DenoiseState<'static>>,
        render: Vec<f32>,
        mono: Vec<f32>,
        cleaned: Vec<f32>,
        scaled_in: Vec<f32>,
        scaled_out: Vec<f32>,
        suppress_noise: bool,
        failed: bool,
        // energy of the speaker reference, the microphone and what is sent, over the blocks since the last line of the log
        levels: [f32; 3],
        level_blocks: u32,
    }

    fn db(sum_of_squares: f32, samples: usize) -> f32 {
        10.0 * (sum_of_squares / samples.max(1) as f32 + 1e-12).log10()
    }

    impl VoiceDsp {
        pub fn new() -> Option<Self> {
            let format = AudioFormat::ten_ms(SAMPLE_RATE, 1);
            let pipeline = match linear::builder(format, format)
                // the noise is taken out by RNNoise, which does it better; a gain control would make the quiet parts of the room loud
                .enable_noise_suppression(false)
                .enable_gain_controller2(false)
                .build()
            {
                Ok(pipeline) => pipeline,
                Err(e) => {
                    log::error!("Echo cancellation could not start: {e}");
                    return None;
                }
            };
            ACTIVE.fetch_add(1, Ordering::Relaxed);
            Some(Self {
                pipeline,
                denoise: DenoiseState::new(),
                render: vec![0.0; FRAME],
                mono: vec![0.0; FRAME],
                cleaned: vec![0.0; FRAME],
                scaled_in: vec![0.0; FRAME],
                scaled_out: vec![0.0; FRAME],
                suppress_noise: true,
                failed: false,
                levels: [0.0; 3],
                level_blocks: 0,
            })
        }

        // What every player of this process gives to the speakers right now, 10 ms.
        fn mix_render(&mut self) {
            self.render.fill(0.0);
            let Ok(mut queues) = QUEUES.lock() else {
                return;
            };
            queues.retain(|queue| match queue.upgrade() {
                Some(queue) => {
                    queue.add_next_frame_to(&mut self.render);
                    true
                }
                None => false,
            });
        }

        /// Cleans one 10 ms block of the microphone in place (`channels` interleaved channels at 48 kHz: the channels are mixed, cleaned, and the
        /// cleaned voice is put in every channel). A block of another size is left as it is.
        pub fn process(&mut self, block: &mut [f32], channels: usize) {
            if self.failed || channels == 0 || block.len() != FRAME * channels {
                return;
            }
            for (m, frame) in self.mono.iter_mut().zip(block.chunks_exact(channels)) {
                *m = frame.iter().sum::<f32>() / channels as f32;
            }
            self.mix_render();
            if let Err(e) = self.pipeline.handle_render_frame(&self.render) {
                log::error!("Echo cancellation stopped (what is played): {e}");
                self.failed = true;
                return;
            }
            match self
                .pipeline
                .process_capture_frame(&self.mono, &mut self.cleaned)
            {
                Ok(true) => {}
                // nothing came out yet (the first blocks): keep the microphone as it is
                Ok(false) => self.cleaned.copy_from_slice(&self.mono),
                Err(e) => {
                    log::error!("Echo cancellation stopped (the microphone): {e}");
                    self.failed = true;
                    return;
                }
            }
            if self.suppress_noise {
                for (s, c) in self.scaled_in.iter_mut().zip(&self.cleaned) {
                    *s = c * S16_SCALE;
                }
                self.denoise
                    .process_frame(&mut self.scaled_out, &self.scaled_in);
                for (c, o) in self.cleaned.iter_mut().zip(&self.scaled_out) {
                    *c = o / S16_SCALE;
                }
            }
            for (frame, voice) in block.chunks_exact_mut(channels).zip(&self.cleaned) {
                frame.fill(voice.clamp(-1.0, 1.0));
            }
            self.levels[0] += self.render.iter().map(|s| s * s).sum::<f32>();
            self.levels[1] += self.mono.iter().map(|s| s * s).sum::<f32>();
            self.levels[2] += self.cleaned.iter().map(|s| s * s).sum::<f32>();
            self.level_blocks += 1;
            if self.level_blocks >= 500 {
                let samples = self.level_blocks as usize * FRAME;
                log::info!(
                    "Voice processing, last 5 s: speaker reference {:.1} dB, microphone {:.1} dB, sent {:.1} dB",
                    db(self.levels[0], samples),
                    db(self.levels[1], samples),
                    db(self.levels[2], samples)
                );
                self.levels = [0.0; 3];
                self.level_blocks = 0;
            }
        }
    }

    impl Drop for VoiceDsp {
        fn drop(&mut self) {
            ACTIVE.fetch_sub(1, Ordering::Relaxed);
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        // a repeatable noise that stands in for a voice
        struct Noise(u32);

        impl Noise {
            fn next(&mut self, amplitude: f32) -> f32 {
                self.0 = self.0.wrapping_mul(1664525).wrapping_add(1013904223);
                ((self.0 >> 8) as f32 / (1u32 << 24) as f32 * 2.0 - 1.0) * amplitude
            }
        }

        fn rms(x: &[f32]) -> f32 {
            (x.iter().map(|s| s * s).sum::<f32>() / x.len().max(1) as f32).sqrt()
        }

        // the feed of a player and the encoder of a microphone of this process, tests do not run in parallel with each other on the counters
        fn serial() -> std::sync::MutexGuard<'static, ()> {
            static LOCK: Mutex<()> = Mutex::new(());
            LOCK.lock().unwrap_or_else(|e| e.into_inner())
        }

        #[test]
        fn a_player_hands_over_nothing_while_no_microphone_is_processed() {
            let _guard = serial();
            let mut feed = RenderFeed::new(48_000, 2);
            feed.push(&[0.5; 960]);
            let mut out = vec![0.0; FRAME];
            feed.queue.add_next_frame_to(&mut out);
            assert!(out.iter().all(|s| *s == 0.0));
        }

        #[test]
        fn the_sound_of_the_speakers_is_mixed_to_mono_and_brought_to_48_khz() {
            let _guard = serial();
            let dsp = VoiceDsp::new().expect("the echo canceller starts");
            let mut stereo = RenderFeed::new(48_000, 2);
            let mut cd = RenderFeed::new(44_100, 1);
            // 100 ms: left 0.4, right 0.2 -> 0.3; and 0.25 at 44.1 kHz -> 0.25 at 48 kHz
            stereo.push(
                &(0..2 * 4800)
                    .map(|i| if i % 2 == 0 { 0.4 } else { 0.2 })
                    .collect::<Vec<_>>(),
            );
            cd.push(&vec![0.25; 4410]);
            let stereo_samples = stereo.queue.state.lock().unwrap().samples.len();
            let cd_samples = cd.queue.state.lock().unwrap().samples.len();
            assert_eq!(stereo_samples, 4800);
            assert!((cd_samples as i64 - 4800).abs() <= 2, "{cd_samples}");
            let mut out = vec![0.0; FRAME];
            stereo.queue.add_next_frame_to(&mut out);
            assert!(out.iter().all(|s| (s - 0.3).abs() < 1e-6));
            let mut out = vec![0.0; FRAME];
            cd.queue.add_next_frame_to(&mut out);
            assert!(out.iter().skip(1).all(|s| (s - 0.25).abs() < 1e-3));
            drop(dsp);
        }

        #[test]
        fn a_player_that_gets_ahead_of_the_microphone_is_cut_back() {
            let _guard = serial();
            let dsp = VoiceDsp::new().expect("the echo canceller starts");
            let mut feed = RenderFeed::new(48_000, 1);
            feed.push(&vec![0.1; SAMPLE_RATE as usize / 2]);
            let mut out = vec![0.0; FRAME];
            feed.queue.add_next_frame_to(&mut out);
            let left = feed.queue.state.lock().unwrap().samples.len();
            assert!(
                left <= PRIME_SAMPLES + FRAME,
                "{left} samples are 500 ms behind"
            );
            drop(dsp);
        }

        // The microphone hears only the speakers (a delayed, weaker copy of what is played, with a second reflection): the cleaned microphone must be
        // much quieter than the raw one once the canceller has learned the room.
        #[test]
        fn the_echo_of_the_speakers_is_taken_out_of_the_microphone() {
            let _guard = serial();
            let mut dsp = VoiceDsp::new().expect("the echo canceller starts");
            // the noise suppressor takes a noise that stands in for a voice for noise: the echo canceller is measured alone
            dsp.suppress_noise = false;
            let mut feed = RenderFeed::new(48_000, 1);
            let mut noise = Noise(7);
            let delay = 2400; // 50 ms from the speakers to the microphone
            let mut played: Vec<f32> = Vec::new();
            let mut raw_tail = Vec::new();
            let mut cleaned_tail = Vec::new();
            let blocks = 1000; // 10 s
            for block_index in 0..blocks {
                // a "voice" that talks in bursts
                let talking = (block_index / 100) % 2 == 0;
                let block: Vec<f32> = (0..FRAME)
                    .map(|_| {
                        if talking {
                            noise.next(0.3)
                        } else {
                            noise.next(0.002)
                        }
                    })
                    .collect();
                // the speakers play it now ...
                feed.push(&block);
                played.extend_from_slice(&block);
                // ... and the microphone hears it later, weaker, with a reflection
                let start = played.len() - FRAME;
                let mut mic: Vec<f32> = (start..start + FRAME)
                    .map(|i| {
                        let d1 = i.checked_sub(delay).map_or(0.0, |j| played[j]);
                        let d2 = i.checked_sub(delay + 480).map_or(0.0, |j| played[j]);
                        0.5 * d1 + 0.2 * d2
                    })
                    .collect();
                let raw = mic.clone();
                dsp.process(&mut mic, 1);
                if block_index >= blocks - 200 && (block_index / 100) % 2 == 0 {
                    raw_tail.extend_from_slice(&raw);
                    cleaned_tail.extend_from_slice(&mic);
                }
            }
            let raw = rms(&raw_tail);
            let cleaned = rms(&cleaned_tail);
            let reduction_db = 20.0 * (raw / cleaned.max(1e-9)).log10();
            println!("echo: raw {raw:.4}, cleaned {cleaned:.4}, reduced by {reduction_db:.1} dB");
            assert!(
                reduction_db > 12.0,
                "the echo was only reduced by {reduction_db:.1} dB"
            );
        }

        // A room with only noise in it must come out much quieter.
        #[test]
        fn steady_noise_is_taken_out_of_the_microphone() {
            let _guard = serial();
            let mut dsp = VoiceDsp::new().expect("the echo canceller starts");
            let mut noise = Noise(11);
            let mut raw_tail = Vec::new();
            let mut cleaned_tail = Vec::new();
            for block_index in 0..300 {
                let mut mic: Vec<f32> = (0..FRAME).map(|_| noise.next(0.05)).collect();
                let raw = mic.clone();
                dsp.process(&mut mic, 1);
                if block_index >= 200 {
                    raw_tail.extend_from_slice(&raw);
                    cleaned_tail.extend_from_slice(&mic);
                }
            }
            let reduction_db = 20.0 * (rms(&raw_tail) / rms(&cleaned_tail).max(1e-9)).log10();
            println!("noise reduced by {reduction_db:.1} dB");
            assert!(
                reduction_db > 10.0,
                "the noise was only reduced by {reduction_db:.1} dB"
            );
        }

        // The person at this computer talks while the speakers play: the voice must stay (a steady tone stands in for it), the echo must go.
        #[test]
        fn the_voice_at_this_computer_stays_while_the_echo_goes() {
            let _guard = serial();
            let mut dsp = VoiceDsp::new().expect("the echo canceller starts");
            dsp.suppress_noise = false;
            let mut feed = RenderFeed::new(48_000, 1);
            let mut noise = Noise(3);
            let delay = 1920;
            let mut played: Vec<f32> = Vec::new();
            let mut near_tail = Vec::new();
            let mut cleaned_tail = Vec::new();
            let mut t = 0usize;
            let blocks = 1200;
            for block_index in 0..blocks {
                let block: Vec<f32> = (0..FRAME).map(|_| noise.next(0.3)).collect();
                feed.push(&block);
                played.extend_from_slice(&block);
                let start = played.len() - FRAME;
                // the voice only talks in the second half, so the canceller has learned the room before
                let talk = block_index >= blocks / 2;
                let mut near = Vec::with_capacity(FRAME);
                let mut mic: Vec<f32> = (start..start + FRAME)
                    .map(|i| {
                        let echo = i.checked_sub(delay).map_or(0.0, |j| 0.5 * played[j]);
                        let voice = if talk {
                            (t as f32 * 300.0 * std::f32::consts::TAU / 48_000.0).sin() * 0.2
                        } else {
                            0.0
                        };
                        t += 1;
                        near.push(voice);
                        echo + voice
                    })
                    .collect();
                dsp.process(&mut mic, 1);
                if block_index >= blocks - 200 {
                    near_tail.extend_from_slice(&near);
                    cleaned_tail.extend_from_slice(&mic);
                }
            }
            let kept_db = 20.0 * (rms(&cleaned_tail) / rms(&near_tail)).log10();
            println!("voice kept: {kept_db:.1} dB (0 = as it was)");
            assert!(
                kept_db > -6.0 && kept_db < 3.0,
                "the voice came out at {kept_db:.1} dB"
            );
        }
        #[test]
        fn a_block_of_another_size_is_left_alone() {
            let _guard = serial();
            let mut dsp = VoiceDsp::new().expect("the echo canceller starts");
            let mut block = vec![0.25; FRAME + 1];
            dsp.process(&mut block, 1);
            assert!(block.iter().all(|s| *s == 0.25));
        }
    }
}
