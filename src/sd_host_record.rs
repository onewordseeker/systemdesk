// SystemDesk: the owner of a computer records what someone does on it. The button in the host window turns this on for the session that is running; the
// video service then also writes what it sends to a file (the same recorder "Automatically record incoming sessions" uses) and stops when it is turned off
// or when nobody is connected any more.
use hbb_common::log;
use std::sync::atomic::{AtomicBool, Ordering};

static ON: AtomicBool = AtomicBool::new(false);

/// The name the host window uses to switch this (the way it switches a permission).
pub const SWITCH_NAME: &str = "sd-host-record";

pub fn is_on() -> bool {
    ON.load(Ordering::Relaxed)
}

/// Where the video service saves a recording. An installed Windows computer lets people in from a process that runs as the system; what it records goes
/// to the Videos folder of the person who is logged in (`C:\Users\<name>\Videos\SystemDesk`), where they look for it. With nobody logged in it is the
/// usual folder of the system.
pub fn save_dir(root: bool) -> String {
    #[cfg(windows)]
    if root {
        if let Some(home) = crate::platform::get_active_user_home() {
            return user_videos_dir(&home);
        }
    }
    crate::ui_interface::video_save_directory(root)
}

#[cfg(windows)]
fn user_videos_dir(home: &std::path::Path) -> String {
    home.join("Videos").join(crate::get_app_name()).to_string_lossy().to_string()
}

pub fn set(on: bool) {
    if ON.swap(on, Ordering::Relaxed) != on {
        log::info!("recording of the session on this computer: {}", if on { "on" } else { "off" });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(windows)]
    #[test]
    fn the_recording_goes_to_the_videos_folder_of_the_person_logged_in() {
        let dir = user_videos_dir(std::path::Path::new(r"C:\Users\Maya"));
        assert_eq!(dir, format!(r"C:\Users\Maya\Videos\{}", crate::get_app_name()));
    }

    // the switch is one global for the whole program: the tests that look at it take turns
    static TURN: std::sync::Mutex<()> = std::sync::Mutex::new(());

    #[test]
    fn nothing_is_recorded_on_this_computer_until_its_owner_asks_for_it() {
        let _turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
        // "Automatically record incoming sessions" is off when it was never set, and the button is off until it is pressed
        assert!(!hbb_common::config::option2bool("allow-auto-record-incoming", ""));
        assert!(hbb_common::config::option2bool("allow-auto-record-incoming", "Y"));
        assert!(!is_on());
    }

    #[test]
    fn it_is_off_until_it_is_switched_on_and_off_again() {
        let _turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
        assert!(!is_on());
        set(true);
        assert!(is_on());
        set(true);
        assert!(is_on());
        set(false);
        assert!(!is_on());
    }
}
