// SystemDesk: the sound output of the controlling computer. The other computer's sound is played on the system's default output unless the person
// chose another one in Settings; a chosen device that is gone (unplugged) falls back to the default.
#![cfg_attr(target_os = "linux", allow(dead_code))]
use cpal::{
    traits::{DeviceTrait, HostTrait},
    Device, Host,
};
use hbb_common::config::{LocalConfig, PeerConfig};

pub const OUTPUT_OPTION: &str = "sd-audio-output";
pub const OUTPUTS_KEY: &str = "sd-audio-outputs";

pub fn output_names() -> Vec<String> {
    let mut names: Vec<String> = cpal::default_host()
        .output_devices()
        .map(|devices| devices.filter_map(|d| d.name().ok()).collect())
        .unwrap_or_default();
    names.sort();
    names.dedup();
    names
}

pub fn outputs_json() -> String {
    serde_json::to_string(&output_names()).unwrap_or_else(|_| "[]".to_owned())
}

fn find_by_name(host: &Host, name: &str) -> Option<Device> {
    host.output_devices()
        .ok()?
        .find(|d| d.name().map_or(false, |n| n == name))
}

const UNMUTED_FLAG: &str = "sd-audio-unmuted";

/// Once, on the first start of a version that has this: every computer saved as "muted" is un-muted (the mute used to be kept per computer without
/// any sign of it in the session, so a person could sit in front of a silent session without knowing why). Later mutes are kept.
pub fn unmute_saved_once() {
    if LocalConfig::get_option(UNMUTED_FLAG) == "Y" {
        return;
    }
    for (id, _, mut config) in PeerConfig::peers(None) {
        if config.disable_audio.v {
            config.disable_audio.v = false;
            config.store(&id);
        }
    }
    LocalConfig::set_option(UNMUTED_FLAG.to_owned(), "Y".to_owned());
}

/// The device the person chose, if there is one and it is there.
pub fn chosen_output(host: &Host) -> Option<Device> {
    let name = LocalConfig::get_option(OUTPUT_OPTION);
    if name.is_empty() {
        return None;
    }
    let found = find_by_name(host, &name);
    if found.is_none() {
        hbb_common::log::warn!("chosen sound output \"{name}\" not found, using the default");
    }
    found
}
