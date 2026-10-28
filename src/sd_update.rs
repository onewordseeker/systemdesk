// SystemDesk: where updates come from.
//
// The app offers the newest release of OUR repository for its channel (not the original project's version server): a TEST build
// (`SD_UPDATE_CHANNEL=test` when it was compiled) follows the pre-releases, a production build the public releases. Every build is its
// own release named by its version (1.7.2); the release goes public only when every platform has been built, so a version that is
// visible always has a file for every platform.
//
// The list and the files come from OUR API (which passes them on from GitHub), so the app only talks to systemdesk.net: it asks the API server
// of its own build (src/sd_servers.rs puts it in force; a test build carries the test API, a production build the production API). The
// addresses under it have GitHub's layout (<owner>/<repo>/releases/tag/<version> and .../releases/download/<version>/<file>).
//
// A DEBUG build can be pointed at a local server for testing with SD_UPDATE_HOST / SD_UPDATE_API; release builds ignore both.
use base::config::keys;
use hbb_common::{config::Config, get_version_number};
use std::{sync::Mutex, time::Duration};

pub const SD_OWNER: &str = "onewordseeker";
pub const SD_REPO: &str = "systemdesk";

/// `test` or `stable`, decided when the app was compiled.
pub fn update_channel() -> &'static str {
    option_env!("SD_UPDATE_CHANNEL").unwrap_or("stable")
}

/// The app checks for updates only when it is SystemDesk (a build under another name keeps the original behaviour).
pub fn updates_enabled() -> bool {
    crate::common::is_custom_client() && crate::common::get_app_name().eq_ignore_ascii_case("systemdesk")
}

/// The copy from the Microsoft Store: the Store updates it, so it never looks for updates or installs one itself.
pub fn store_copy() -> bool {
    #[cfg(target_os = "windows")]
    {
        crate::platform::windows::is_msix_package()
    }
    #[cfg(not(target_os = "windows"))]
    {
        false
    }
}

pub fn update_host() -> String {
    #[cfg(debug_assertions)]
    if let Ok(h) = std::env::var("SD_UPDATE_HOST") {
        if !h.is_empty() {
            return h.trim_end_matches('/').to_owned();
        }
    }
    // the API server of this build (a debug app: the one its launcher saved); no address is written in this code
    updates_under(&Config::get_option("api-server"))
}

fn updates_under(api: &str) -> String {
    format!("{}/api/updates", api.trim_end_matches('/'))
}

/// Tests only: an API server for the tests (an example address), whatever the developer's own copy of the app saved.
#[cfg(test)]
pub fn use_test_api_server() {
    hbb_common::config::OVERWRITE_SETTINGS
        .write()
        .unwrap()
        .insert("api-server".to_owned(), "https://api.systemdesk.net".to_owned());
}

pub fn update_api() -> String {
    #[cfg(debug_assertions)]
    if let Ok(a) = std::env::var("SD_UPDATE_API") {
        if !a.is_empty() {
            return a;
        }
    }
    format!("{}/releases", update_host())
}

pub fn release_page_url(tag: &str) -> String {
    format!("{}/{SD_OWNER}/{SD_REPO}/releases/tag/{tag}", update_host())
}

/// Debug builds only: a download from the local test server (SD_UPDATE_HOST=http://127.0.0.1:...) may use plain http. Release builds
/// always answer false: a download must be https.
#[cfg(debug_assertions)]
pub fn is_local_test_url(url: &str) -> bool {
    let host = update_host();
    host.starts_with("http://127.0.0.1") && url.starts_with(&format!("{host}/"))
}

#[cfg(not(debug_assertions))]
pub fn is_local_test_url(_url: &str) -> bool {
    false
}

/// A release tag is a version: three numbers of at most three digits ("1.7.2"). Anything else (the old rolling "test" tag, "nightly") is
/// not an update.
pub fn is_version_tag(tag: &str) -> bool {
    let parts: Vec<&str> = tag.split('.').collect();
    parts.len() == 3
        && parts
            .iter()
            .all(|p| !p.is_empty() && p.len() <= 3 && p.bytes().all(|b| b.is_ascii_digit()))
}

/// The tag of the newest release this channel should be offered, out of GitHub's list of releases: not a draft, a pre-release exactly when
/// the channel is `test`, and a version tag.
pub fn pick_release(releases: &serde_json::Value, channel: &str) -> Option<String> {
    let want_prerelease = channel == "test";
    releases
        .as_array()?
        .iter()
        .filter_map(|r| {
            if r.get("draft").and_then(|v| v.as_bool()).unwrap_or(false) {
                return None;
            }
            if r.get("prerelease").and_then(|v| v.as_bool()).unwrap_or(false) != want_prerelease {
                return None;
            }
            let tag = r.get("tag_name")?.as_str()?;
            is_version_tag(tag).then(|| tag.to_owned())
        })
        .max_by_key(|t| get_version_number(t))
}

/// How a check ended, as the About page gets it: `available` (with the release page), `latest`, `error`, or `off` (this build does not look
/// for updates). `None` = the check failed, `Some("")` = nothing newer, `Some(url)` = a newer version.
fn describe_check(outcome: Option<&str>) -> String {
    match outcome {
        None => serde_json::json!({ "status": "error" }),
        Some("") => serde_json::json!({ "status": "latest" }),
        Some(url) => serde_json::json!({ "status": "available", "url": url }),
    }
    .to_string()
}

/// SystemDesk updates itself unless the person turned that off (Settings -> About). The option is `allow-auto-update`: "N" is off, anything else
/// (also never set) is on. A build under another name keeps the original behaviour: off until it is switched on.
pub fn auto_update_allowed() -> bool {
    if updates_enabled() {
        auto_update_value_is_on(&Config::get_option(keys::OPTION_ALLOW_AUTO_UPDATE))
    } else {
        Config::get_bool_option(keys::OPTION_ALLOW_AUTO_UPDATE)
    }
}

fn auto_update_value_is_on(value: &str) -> bool {
    value != "N"
}

/// How often the background check runs: every 3 hours (the original project asks once a day).
pub fn auto_check_every(original: Duration) -> Duration {
    if updates_enabled() {
        Duration::from_secs(3 * 60 * 60)
    } else {
        original
    }
}

// An installer that cannot do its job (blocked, a missing right) would be started again every half hour for ever.
const MAX_INSTALL_TRIES: u32 = 3;

lazy_static::lazy_static! {
    static ref INSTALL_TRIES: Mutex<(String, u32)> = Default::default();
}

/// May the background updater start the installer of this version now? A version is tried a few times; after that it is left alone until the
/// app starts again.
#[allow(dead_code)]
pub fn may_try_install(version: &str) -> bool {
    let Ok(mut tries) = INSTALL_TRIES.lock() else {
        return false;
    };
    if tries.0 != version {
        *tries = (version.to_owned(), 0);
    }
    if tries.1 >= MAX_INSTALL_TRIES {
        return false;
    }
    tries.1 += 1;
    true
}

/// A check the person asked for (Settings -> About -> Check for updates, also made when About is opened). The same check the app makes by
/// itself, but it says how it ended once the answer is in. Blocks until then, so call it off the UI thread.
pub fn check_now() -> String {
    if !updates_enabled() || store_copy() {
        return serde_json::json!({ "status": "off" }).to_string();
    }
    let outcome = std::thread::spawn(crate::common::do_check_software_update)
        .join()
        .map_err(|_| hbb_common::anyhow::anyhow!("the update check stopped unexpectedly"))
        .and_then(|r| r);
    match outcome {
        Ok(()) => {
            let url = crate::common::SOFTWARE_UPDATE_URL.lock().unwrap().clone();
            describe_check(Some(&url))
        }
        Err(e) => {
            hbb_common::log::warn!("The update check failed: {e}");
            describe_check(None)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn a_check_is_described_for_the_about_page() {
        let v = |s: String| serde_json::from_str::<serde_json::Value>(&s).unwrap();
        assert_eq!(v(describe_check(None)), json!({ "status": "error" }));
        assert_eq!(v(describe_check(Some(""))), json!({ "status": "latest" }));
        let url = "https://api.systemdesk.net/api/updates/onewordseeker/systemdesk/releases/tag/1.5.7";
        assert_eq!(v(describe_check(Some(url))), json!({ "status": "available", "url": url }));
    }

    #[test]
    fn updating_by_itself_is_on_unless_it_was_turned_off() {
        assert!(auto_update_value_is_on(""), "never set: on");
        assert!(auto_update_value_is_on("Y"));
        assert!(auto_update_value_is_on("anything else"));
        assert!(!auto_update_value_is_on("N"));
    }

    #[test]
    fn an_installer_is_tried_a_few_times_per_version() {
        assert!(may_try_install("9.9.1"));
        assert!(may_try_install("9.9.1"));
        assert!(may_try_install("9.9.1"));
        assert!(!may_try_install("9.9.1"), "the fourth try is refused");
        assert!(!may_try_install("9.9.1"));
        assert!(may_try_install("9.9.2"), "another version starts again");
        assert!(may_try_install("9.9.2"));
    }

    fn rel(tag: &str, prerelease: bool, draft: bool) -> serde_json::Value {
        json!({ "tag_name": tag, "prerelease": prerelease, "draft": draft })
    }

    #[test]
    fn only_version_tags_are_versions() {
        for ok in ["1.5.0", "1.7.12", "10.0.1", "999.999.999"] {
            assert!(is_version_tag(ok), "{ok}");
        }
        for bad in ["test", "nightly", "1.5", "1.5.0.1", "v1.5.0", "1.5.0-beta", "1..0", "1.5.1000", "", "a.b.c", "1.5.-1"] {
            assert!(!is_version_tag(bad), "{bad}");
        }
    }

    #[test]
    fn the_newest_version_wins_by_number_not_by_text() {
        let list = json!([rel("1.5.9", true, false), rel("1.5.10", true, false), rel("1.5.2", true, false)]);
        assert_eq!(pick_release(&list, "test").as_deref(), Some("1.5.10"));
        let list = json!([rel("1.9.9", true, false), rel("1.10.0", true, false)]);
        assert_eq!(pick_release(&list, "test").as_deref(), Some("1.10.0"));
    }

    #[test]
    fn a_test_app_follows_pre_releases_a_production_app_follows_public_releases() {
        let list = json!([rel("1.6.1", true, false), rel("1.6.0", false, false), rel("1.5.0", false, false), rel("1.6.2", true, false)]);
        assert_eq!(pick_release(&list, "test").as_deref(), Some("1.6.2"));
        assert_eq!(pick_release(&list, "stable").as_deref(), Some("1.6.0"));
    }

    #[test]
    fn a_draft_is_never_offered() {
        let list = json!([rel("1.6.1", true, true), rel("1.6.0", true, false)]);
        assert_eq!(pick_release(&list, "test").as_deref(), Some("1.6.0"));
        assert_eq!(pick_release(&json!([rel("1.6.1", true, true)]), "test"), None);
    }

    #[test]
    fn rolling_tags_and_rubbish_are_ignored() {
        let list = json!([rel("test", true, false), rel("nightly", false, false), rel("1.5.0", true, false), {"nothing": 1}, 7]);
        assert_eq!(pick_release(&list, "test").as_deref(), Some("1.5.0"));
        assert_eq!(pick_release(&json!({"message": "rate limited"}), "test"), None);
        assert_eq!(pick_release(&json!([]), "test"), None);
    }

    #[test]
    fn an_update_means_a_higher_number() {
        let cur = get_version_number("1.5.0");
        assert!(get_version_number("1.5.1") > cur);
        assert!(get_version_number("1.6.0") > cur);
        assert!(get_version_number("2.0.0") > cur);
        assert!(get_version_number("1.5.0") <= cur);
        assert!(get_version_number("1.4.99") < cur);
    }

    #[test]
    fn the_release_page_is_ours() {
        use_test_api_server();
        let host = update_host();
        assert!(host.ends_with("/api/updates"), "{host}");
        assert!(crate::sd_lock::is_ours(&host), "{host}");
        assert_eq!(
            release_page_url("1.5.1"),
            format!("{host}/onewordseeker/systemdesk/releases/tag/1.5.1")
        );
        assert_eq!(update_api(), format!("{host}/releases"));
    }

    #[test]
    fn a_build_asks_the_api_server_it_carries() {
        use_test_api_server();
        assert_eq!(update_host(), "https://api.systemdesk.net/api/updates");
        // a trailing slash makes no difference
        assert_eq!(updates_under("https://api.systemdesk.net/"), "https://api.systemdesk.net/api/updates");
        assert_eq!(updates_under("https://api.systemdesk.net"), "https://api.systemdesk.net/api/updates");
    }
}
