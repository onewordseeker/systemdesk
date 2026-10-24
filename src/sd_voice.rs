// SystemDesk: the microphone of a voice call is its own switch.
//
// A voice call sends the voice of the person who controls (the microphone) to the controlled computer. The "sound" of a session (the audio of the
// controlled computer, muted with "Mute") is another thing. They used to share one stream, so muting the sound muted the call and a call replaced the
// sound of the computer with the microphone. A call with split streams keeps them apart:
//   - stream 0 is the sound of the controlled computer (what it plays), whether or not a call is running;
//   - stream 1 is the voice of the person at the controlled computer (its microphone), only while a call runs.
// The microphone of the person who controls goes the other way in the frames the call has always used. It can be muted on its own, for the call that is
// running (a call always starts with the microphone on). Computers that do not know about split streams keep the old single stream.
use std::{
    collections::HashSet,
    sync::{
        atomic::{AtomicBool, AtomicUsize, Ordering},
        Mutex,
    },
};

pub const STREAM_SOUND: u32 = 0;
pub const STREAM_VOICE: u32 = 1;

/// The controlled computer can capture its microphone next to the sound of the computer.
pub const SPLIT_STREAMS_SUPPORTED: bool = cfg!(any(target_os = "windows", target_os = "macos"));

lazy_static::lazy_static! {
    // the computers (by their id) whose call has the microphone muted
    static ref MIC_MUTED: Mutex<HashSet<String>> = Default::default();
}

// the calls with split streams that run on this (controlled) computer
static SPLIT_CALLS: AtomicUsize = AtomicUsize::new(0);
// the microphone of this (controlled) computer is muted for the call, with the button of the connection window
static HOST_MIC_MUTED: AtomicBool = AtomicBool::new(false);

/// The person at the controlled computer mutes or unmutes the microphone that the call sends. A call always starts with it on.
pub fn set_host_mic_muted(muted: bool) {
    HOST_MIC_MUTED.store(muted, Ordering::SeqCst);
}

#[inline]
pub fn host_mic_muted() -> bool {
    HOST_MIC_MUTED.load(Ordering::Relaxed)
}

/// What the connection window asks the service for ("Y" = muted).
pub fn host_mic_muted_text() -> String {
    if host_mic_muted() { "Y" } else { "N" }.to_owned()
}

pub fn set_mic_muted(peer: &str, muted: bool) {
    if let Ok(mut m) = MIC_MUTED.lock() {
        if muted {
            m.insert(peer.to_owned());
        } else {
            m.remove(peer);
        }
    }
}

pub fn is_mic_muted(peer: &str) -> bool {
    MIC_MUTED.lock().map(|m| m.contains(peer)).unwrap_or(false)
}

#[inline]
pub fn split_call_active() -> bool {
    SPLIT_CALLS.load(Ordering::SeqCst) > 0
}

/// A call with split streams starts on this computer: the sound is captured without what this app plays (the voice of the caller), so it does not
/// come back as an echo.
pub fn split_call_started() {
    SPLIT_CALLS.fetch_add(1, Ordering::SeqCst);
    crate::audio_service::restart();
}

pub fn split_call_ended() {
    let was = SPLIT_CALLS.fetch_update(Ordering::SeqCst, Ordering::SeqCst, |n| n.checked_sub(1));
    if was.is_ok() {
        crate::audio_service::restart();
    }
}

/// Does the controlled computer send the microphone of a call with split streams? It depends on the call only: the "sound" permission and the
/// controller's Sound button are about what the computer plays.
#[inline]
pub fn voice_stream_wanted(split_call: bool) -> bool {
    split_call
}

/// Does the controlled computer send the sound stream? The sound permission and the controller's Sound button decide; a call without split streams
/// (an older controller) sends its microphone in that stream, so it needs the stream whatever they say (it carries nothing but the microphone then).
#[inline]
pub fn sound_stream_wanted(audio_permission: bool, disable_audio: bool, unsplit_call: bool) -> bool {
    (audio_permission && !disable_audio) || unsplit_call
}

/// What the answer to a call request says about split streams: only when the caller asked for them and this computer can do them.
#[inline]
pub fn split_streams_agreed(requested: bool) -> bool {
    requested && SPLIT_STREAMS_SUPPORTED
}

/// The stream a frame or a format message belongs to, from the service that produced it.
#[inline]
pub fn stream_of_service(name: &str) -> u32 {
    if name == crate::audio_service::VOICE_NAME {
        STREAM_VOICE
    } else {
        STREAM_SOUND
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_microphone_is_muted_per_computer_and_starts_on() {
        assert!(!is_mic_muted("sd-voice-a"));
        set_mic_muted("sd-voice-a", true);
        assert!(is_mic_muted("sd-voice-a"));
        assert!(
            !is_mic_muted("sd-voice-b"),
            "another computer's call is not affected"
        );
        set_mic_muted("sd-voice-a", false);
        assert!(!is_mic_muted("sd-voice-a"));
        set_mic_muted("sd-voice-a", false);
        assert!(!is_mic_muted("sd-voice-a"), "unmuting twice is fine");
    }

    #[test]
    fn frames_belong_to_the_stream_of_the_service_that_made_them() {
        assert_eq!(stream_of_service(crate::audio_service::NAME), STREAM_SOUND);
        assert_eq!(
            stream_of_service(crate::audio_service::VOICE_NAME),
            STREAM_VOICE
        );
        assert_eq!(stream_of_service("something else"), STREAM_SOUND);
    }

    #[test]
    fn the_voice_of_a_call_does_not_depend_on_the_sound_permission_or_button() {
        // a call with split streams sends the microphone; nothing about "sound" is asked
        assert!(voice_stream_wanted(true));
        assert!(!voice_stream_wanted(false));
        // the sound stream follows the permission and the Sound button when there is no unsplit call
        for (audio, disable, want) in [(true, false, true), (true, true, false), (false, false, false), (false, true, false)] {
            assert_eq!(sound_stream_wanted(audio, disable, false), want);
        }
        // an unsplit call (an older controller) keeps its microphone whatever the sound permission and the Sound button say
        for (audio, disable) in [(true, false), (true, true), (false, false), (false, true)] {
            assert!(sound_stream_wanted(audio, disable, true));
        }
    }

    #[test]
    fn split_streams_need_the_caller_to_ask_and_the_computer_to_be_able() {
        assert!(!split_streams_agreed(false));
        assert_eq!(split_streams_agreed(true), SPLIT_STREAMS_SUPPORTED);
    }
}

// Needs the real sound devices of the computer it runs on (and plays an alarm on them): run by hand with
//   cargo test --features hwcodec,flutter --lib split_call -- --ignored --nocapture
#[cfg(all(test, windows))]
mod live_tests {
    use super::*;
    use crate::{audio_service, ConnInner};
    use base::message_proto::{message, misc};
    use hbb_common::tokio::sync::mpsc::unbounded_channel;
    use std::time::{Duration, Instant};

    #[test]
    #[ignore = "uses the real sound devices of this computer"]
    fn a_split_call_sends_the_sound_and_the_voice_as_two_tagged_streams() {
        let server = crate::server::new();
        let (tx, mut rx) = unbounded_channel();
        let id = server.write().unwrap().get_new_id();
        let conn = ConnInner::new(id, Some(tx), None);
        server
            .write()
            .unwrap()
            .subscribe(audio_service::NAME, conn.clone(), true);
        split_call_started();
        server
            .write()
            .unwrap()
            .subscribe(audio_service::VOICE_NAME, conn.clone(), true);
        let mut player = std::process::Command::new("powershell")
            .args([
                "-NoProfile",
                "-Command",
                "(New-Object Media.SoundPlayer 'C:\\Windows\\Media\\Alarm05.wav').PlaySync()",
            ])
            .spawn()
            .unwrap();
        let mut formats = [0usize; 2];
        let mut frames = [0usize; 2];
        let until = Instant::now() + Duration::from_secs(6);
        while Instant::now() < until {
            match rx.try_recv() {
                Ok((_, msg)) => match &msg.union {
                    Some(message::Union::Misc(m)) => {
                        if let Some(misc::Union::AudioFormat(f)) = &m.union {
                            formats[(f.stream as usize).min(1)] += 1;
                        }
                    }
                    Some(message::Union::AudioFrame(f)) => frames[(f.stream as usize).min(1)] += 1,
                    _ => {}
                },
                Err(_) => std::thread::sleep(Duration::from_millis(5)),
            }
        }
        let _ = player.kill();
        server
            .write()
            .unwrap()
            .subscribe(audio_service::VOICE_NAME, conn.clone(), false);
        split_call_ended();
        println!("formats (sound, voice): {formats:?}; frames (sound, voice): {frames:?}");
        assert!(
            formats[0] >= 1 && frames[0] > 0,
            "the sound of the computer is sent as stream 0"
        );
        if crate::get_default_sound_input().is_some() {
            assert!(
                formats[1] >= 1 && frames[1] > 0,
                "the microphone is sent as stream 1"
            );
        } else {
            println!("no microphone in this session: the voice stream was not checked");
        }
        assert!(!split_call_active());
    }
}
