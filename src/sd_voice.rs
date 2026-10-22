// SystemDesk: the microphone of a voice call is its own switch.
//
// A voice call sends the voice of the person who controls (the microphone) to the controlled computer. The "sound" of a session (the audio of the
// controlled computer, muted with "Mute") is another thing: muting it used to mute the voice call as well, because the controlled side dropped the
// caller's audio whenever the session's audio was off. The microphone can now be muted on its own, for the call that is running (a call always
// starts with the microphone on), and the sound can be off while the caller is heard.
use std::{collections::HashSet, sync::Mutex};

lazy_static::lazy_static! {
    // the computers (by their id) whose call has the microphone muted
    static ref MIC_MUTED: Mutex<HashSet<String>> = Default::default();
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_microphone_is_muted_per_computer_and_starts_on() {
        assert!(!is_mic_muted("sd-voice-a"));
        set_mic_muted("sd-voice-a", true);
        assert!(is_mic_muted("sd-voice-a"));
        assert!(!is_mic_muted("sd-voice-b"), "another computer's call is not affected");
        set_mic_muted("sd-voice-a", false);
        assert!(!is_mic_muted("sd-voice-a"));
        set_mic_muted("sd-voice-a", false);
        assert!(!is_mic_muted("sd-voice-a"), "unmuting twice is fine");
    }
}
