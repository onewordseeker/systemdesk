// SystemDesk, Windows 10 (version 2004) and later: the sound of the computer without what this process plays.
//
// While a voice call runs, the voice of the caller is played by this process, on the same speakers as everything else. A plain loopback capture
// of those speakers takes that voice back in and sends it to the caller as an echo. The process loopback of Windows leaves one process (and its
// children) out of the capture, so the sound of the computer reaches the caller without the caller's own voice.
// https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording#capturing-audio-from-a-process
use cpal::{traits::StreamTrait, PauseStreamError, PlayStreamError};
use hbb_common::{
    anyhow::{anyhow, bail},
    log, ResultType,
};
use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc, Arc,
    },
    thread::JoinHandle,
    time::Duration,
};
use windows::{
    core::{implement, Interface, Ref, HRESULT},
    Win32::{
        Foundation::{CloseHandle, HANDLE, WAIT_OBJECT_0},
        Media::Audio::{
            ActivateAudioInterfaceAsync, IActivateAudioInterfaceAsyncOperation,
            IActivateAudioInterfaceCompletionHandler,
            IActivateAudioInterfaceCompletionHandler_Impl, IAudioCaptureClient, IAudioClient,
            AUDCLNT_BUFFERFLAGS_SILENT, AUDCLNT_SHAREMODE_SHARED,
            AUDCLNT_STREAMFLAGS_EVENTCALLBACK, AUDCLNT_STREAMFLAGS_LOOPBACK,
            AUDIOCLIENT_ACTIVATION_PARAMS, AUDIOCLIENT_ACTIVATION_PARAMS_0,
            AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK, AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS,
            PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE,
            VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK, WAVEFORMATEX,
        },
        System::{
            Com::{
                CoInitializeEx, CoUninitialize, StructuredStorage::PROPVARIANT, BLOB,
                COINIT_MULTITHREADED,
            },
            Threading::{CreateEventW, GetCurrentProcessId, SetEvent, WaitForSingleObject},
            Variant::VT_BLOB,
        },
    },
};

// The process loopback has no mix format to ask for: the format of the capture is set here.
pub(super) const SAMPLE_RATE: u32 = 48_000;
pub(super) const CHANNELS: u16 = 2;
const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;
const BITS_PER_SAMPLE: u16 = 32;
const BUFFER_DURATION_100NS: i64 = 200_000; // 20 ms
const ACTIVATION_TIMEOUT_MS: u32 = 5_000;
const WAKE_INTERVAL_MS: u32 = 100;
const START_TIMEOUT: Duration = Duration::from_secs(10);

#[implement(IActivateAudioInterfaceCompletionHandler)]
struct ActivationDone {
    // an event handle, as a number so that the object can be shared with the thread that completes the activation
    event: isize,
}

impl IActivateAudioInterfaceCompletionHandler_Impl for ActivationDone_Impl {
    fn ActivateCompleted(
        &self,
        _operation: Ref<'_, IActivateAudioInterfaceAsyncOperation>,
    ) -> windows::core::Result<()> {
        unsafe { SetEvent(HANDLE(self.event as _)) }
    }
}

struct OwnedHandle(HANDLE);

impl Drop for OwnedHandle {
    fn drop(&mut self) {
        unsafe {
            let _ = CloseHandle(self.0);
        }
    }
}

unsafe fn activate_client_without_audio_of(process: u32) -> ResultType<IAudioClient> {
    let mut params = AUDIOCLIENT_ACTIVATION_PARAMS {
        ActivationType: AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK,
        Anonymous: AUDIOCLIENT_ACTIVATION_PARAMS_0 {
            ProcessLoopbackParams: AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS {
                TargetProcessId: process,
                ProcessLoopbackMode: PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE,
            },
        },
    };
    // The blob points at `params` on this stack, which PropVariantClear must never free.
    let mut prop = std::mem::ManuallyDrop::new(PROPVARIANT::default());
    {
        let inner = &mut *prop.Anonymous.Anonymous;
        inner.vt = VT_BLOB;
        inner.Anonymous.blob = BLOB {
            cbSize: std::mem::size_of::<AUDIOCLIENT_ACTIVATION_PARAMS>() as u32,
            pBlobData: &mut params as *mut AUDIOCLIENT_ACTIVATION_PARAMS as *mut u8,
        };
    }
    let event = OwnedHandle(CreateEventW(None, false, false, None)?);
    let handler: IActivateAudioInterfaceCompletionHandler = ActivationDone {
        event: event.0 .0 as isize,
    }
    .into();
    let operation = ActivateAudioInterfaceAsync(
        VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK,
        &IAudioClient::IID,
        Some(&*prop),
        &handler,
    )?;
    if WaitForSingleObject(event.0, ACTIVATION_TIMEOUT_MS) != WAIT_OBJECT_0 {
        bail!("The activation of the process loopback did not finish");
    }
    let mut result = HRESULT(0);
    let mut activated = None;
    operation.GetActivateResult(&mut result, &mut activated)?;
    result.ok()?;
    let client = activated
        .ok_or_else(|| anyhow!("The process loopback activation returned no interface"))?
        .cast::<IAudioClient>()?;
    Ok(client)
}

unsafe fn open_capture(
    process: u32,
) -> ResultType<(IAudioClient, IAudioCaptureClient, OwnedHandle)> {
    let client = activate_client_without_audio_of(process)?;
    let bytes_per_frame = CHANNELS * BITS_PER_SAMPLE / 8;
    let format = WAVEFORMATEX {
        wFormatTag: WAVE_FORMAT_IEEE_FLOAT,
        nChannels: CHANNELS,
        nSamplesPerSec: SAMPLE_RATE,
        nAvgBytesPerSec: SAMPLE_RATE * bytes_per_frame as u32,
        nBlockAlign: bytes_per_frame,
        wBitsPerSample: BITS_PER_SAMPLE,
        cbSize: 0,
    };
    client.Initialize(
        AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
        BUFFER_DURATION_100NS,
        0,
        &format,
        None,
    )?;
    let wake = OwnedHandle(CreateEventW(None, false, false, None)?);
    client.SetEventHandle(wake.0)?;
    let capture = client.GetService::<IAudioCaptureClient>()?;
    client.Start()?;
    Ok((client, capture, wake))
}

// Hands every block that is ready to `on_samples`. Err = the capture is gone and has to be created again.
unsafe fn drain(
    capture: &IAudioCaptureClient,
    samples: &mut Vec<f32>,
    on_samples: &mut impl FnMut(&[f32]),
) -> ResultType<()> {
    loop {
        if capture.GetNextPacketSize()? == 0 {
            return Ok(());
        }
        let mut data: *mut u8 = std::ptr::null_mut();
        let mut frames = 0u32;
        let mut flags = 0u32;
        capture.GetBuffer(&mut data, &mut frames, &mut flags, None, None)?;
        let count = frames as usize * CHANNELS as usize;
        samples.clear();
        if flags & AUDCLNT_BUFFERFLAGS_SILENT.0 as u32 != 0 || data.is_null() {
            samples.resize(count, 0.0);
        } else {
            let bytes = std::slice::from_raw_parts(data, count * std::mem::size_of::<f32>());
            samples.extend(
                bytes
                    .chunks_exact(std::mem::size_of::<f32>())
                    .map(|b| f32::from_le_bytes([b[0], b[1], b[2], b[3]])),
            );
        }
        capture.ReleaseBuffer(frames)?;
        on_samples(samples);
    }
}

fn capture_thread(
    process: u32,
    stop: Arc<AtomicBool>,
    started: mpsc::Sender<Result<(), String>>,
    mut on_samples: impl FnMut(&[f32]),
    on_failure: impl FnOnce(),
) {
    unsafe {
        if let Err(e) = CoInitializeEx(None, COINIT_MULTITHREADED).ok() {
            let _ = started.send(Err(format!("{e}")));
            return;
        }
        match open_capture(process) {
            Err(e) => {
                let _ = started.send(Err(format!("{e:#}")));
            }
            Ok((client, capture, wake)) => {
                let _ = started.send(Ok(()));
                let mut samples =
                    Vec::with_capacity(SAMPLE_RATE as usize / 100 * CHANNELS as usize);
                let mut failed = None;
                while !stop.load(Ordering::SeqCst) {
                    // nothing is signalled while the computer is silent
                    if WaitForSingleObject(wake.0, WAKE_INTERVAL_MS) != WAIT_OBJECT_0 {
                        continue;
                    }
                    if let Err(e) = drain(&capture, &mut samples, &mut on_samples) {
                        failed = Some(e);
                        break;
                    }
                }
                let _ = client.Stop();
                if let Some(e) = failed {
                    log::warn!("The process loopback capture stopped: {e:#}");
                    on_failure();
                }
            }
        }
        CoUninitialize();
    }
}

pub(super) struct ProcessLoopbackCapture {
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
}

impl ProcessLoopbackCapture {
    /// Starts the capture; Err when this Windows cannot leave a process out (before Windows 10 version 2004) or the audio service is not there.
    pub(super) fn start(
        on_samples: impl FnMut(&[f32]) + Send + 'static,
        on_failure: impl FnOnce() + Send + 'static,
    ) -> ResultType<Self> {
        Self::start_without_audio_of(unsafe { GetCurrentProcessId() }, on_samples, on_failure)
    }

    /// Like `start`, leaving out the audio of `process` (and its children) instead of this process.
    pub(super) fn start_without_audio_of(
        process: u32,
        on_samples: impl FnMut(&[f32]) + Send + 'static,
        on_failure: impl FnOnce() + Send + 'static,
    ) -> ResultType<Self> {
        let stop = Arc::new(AtomicBool::new(false));
        let (started_tx, started_rx) = mpsc::channel();
        let thread = std::thread::Builder::new()
            .name("audio-process-loopback".to_owned())
            .spawn({
                let stop = stop.clone();
                move || capture_thread(process, stop, started_tx, on_samples, on_failure)
            })?;
        let started = started_rx.recv_timeout(START_TIMEOUT);
        let capture = Self {
            stop,
            thread: Some(thread),
        };
        match started {
            Ok(Ok(())) => Ok(capture),
            Ok(Err(e)) => bail!("{e}"),
            Err(_) => bail!("The process loopback capture did not start in time"),
        }
    }
}

impl StreamTrait for ProcessLoopbackCapture {
    fn play(&self) -> Result<(), PlayStreamError> {
        Ok(())
    }

    fn pause(&self) -> Result<(), PauseStreamError> {
        Ok(())
    }
}

impl Drop for ProcessLoopbackCapture {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
    use std::sync::{atomic::AtomicUsize, Mutex};

    const PLAYER: &str =
        "(New-Object Media.SoundPlayer 'C:\\Windows\\Media\\Alarm01.wav').PlaySync()";

    struct Meter {
        peak: Arc<Mutex<f32>>,
        blocks: Arc<AtomicUsize>,
    }

    impl Meter {
        fn new() -> Self {
            Self {
                peak: Arc::new(Mutex::new(0.0)),
                blocks: Arc::new(AtomicUsize::new(0)),
            }
        }

        fn on_samples(&self) -> impl FnMut(&[f32]) + Send + 'static {
            let (peak, blocks) = (self.peak.clone(), self.blocks.clone());
            move |data| {
                blocks.fetch_add(1, Ordering::SeqCst);
                let p = data.iter().fold(0f32, |m, s| m.max(s.abs()));
                let mut w = peak.lock().unwrap();
                *w = w.max(p);
            }
        }

        fn take_peak(&self) -> f32 {
            std::mem::take(&mut *self.peak.lock().unwrap())
        }
    }

    fn play_tone_for(duration: Duration) {
        let device = cpal::default_host()
            .default_output_device()
            .expect("an output device");
        let config = device.default_output_config().expect("an output config");
        assert_eq!(config.sample_format(), cpal::SampleFormat::F32);
        let channels = config.channels() as usize;
        let rate = config.sample_rate().0 as f32;
        let mut t = 0f32;
        let stream = device
            .build_output_stream(
                &config.config(),
                move |out: &mut [f32], _| {
                    for frame in out.chunks_mut(channels) {
                        let v = (t * 440.0 * std::f32::consts::TAU).sin() * 0.5;
                        t += 1.0 / rate;
                        frame.iter_mut().for_each(|s| *s = v);
                    }
                },
                |e| panic!("{e}"),
                None,
            )
            .expect("an output stream");
        stream.play().unwrap();
        std::thread::sleep(duration);
    }

    fn play_alarm_in_a_child_process() {
        let status = std::process::Command::new("powershell")
            .args(["-NoProfile", "-Command", PLAYER])
            .status()
            .unwrap();
        assert!(status.success());
    }

    // These play on the real default output device. Run by hand:
    //   cargo test --lib process_loopback -- --ignored --nocapture --test-threads=1
    #[test]
    #[ignore = "plays sound on the default output device"]
    fn process_loopback_leaves_out_this_process_and_its_children() {
        let meter = Meter::new();
        let capture =
            ProcessLoopbackCapture::start(meter.on_samples(), || println!("capture failed"))
                .expect("the process loopback starts (Windows 10 version 2004 or later)");
        play_tone_for(Duration::from_millis(1500));
        let tone = meter.take_peak();
        play_alarm_in_a_child_process();
        let child = meter.take_peak();
        let blocks = meter.blocks.load(Ordering::SeqCst);
        drop(capture);
        println!("peak of the tone of this process: {tone}; of a child process: {child}; blocks: {blocks}");
        assert!(blocks > 0, "the capture delivered nothing");
        assert!(tone < 0.001, "the tone of this process came back: {tone}");
        assert!(
            child < 0.001,
            "the sound of a child process came back: {child}"
        );
    }

    #[test]
    #[ignore = "plays sound on the default output device"]
    fn process_loopback_captures_what_other_processes_play() {
        // leave out an unrelated process: this process and the player are not part of its tree
        let mut other = std::process::Command::new("ping")
            .args(["-n", "30", "127.0.0.1"])
            .stdout(std::process::Stdio::null())
            .spawn()
            .unwrap();
        let meter = Meter::new();
        let capture =
            ProcessLoopbackCapture::start_without_audio_of(other.id(), meter.on_samples(), || {
                println!("capture failed")
            })
            .expect("the process loopback starts (Windows 10 version 2004 or later)");
        play_alarm_in_a_child_process();
        let alarm = meter.take_peak();
        drop(capture);
        let _ = other.kill();
        println!("peak of the alarm of a process that is not left out: {alarm}");
        assert!(
            alarm > 0.01,
            "the sound of another process was not captured: {alarm}"
        );
    }
}
