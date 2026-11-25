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

// Signed releases. An installer is started with elevated rights, so what the update API passes on is not trusted by itself: every release
// carries SHA256SUMS.txt and its signature (SHA256SUMS.txt.sig, hex), made on the release machine with a key that is never on a server, in the
// build or on GitHub. Nothing that was downloaded is started before the signature and the file's hash have been checked.

/// The public half of the release signing key.
const RELEASE_SIGNING_PUBLIC_KEY: [u8; 32] = [
    0xec, 0xe9, 0x3e, 0xa4, 0x0c, 0xd5, 0xec, 0xcb, 0x5a, 0xa1, 0x01, 0x6e, 0x63, 0xc8, 0xe9, 0x48, 0x1c,
    0xd0, 0x40, 0xec, 0x55, 0xd6, 0x44, 0xc6, 0x4f, 0x9f, 0x1f, 0xc3, 0x0f, 0x5a, 0xe7, 0xfd,
];

#[allow(dead_code)]
pub enum DownloadCheck {
    Good,
    /// The signature is not there yet (or could not be fetched): nothing is installed now, the next check tries again.
    NotYet(String),
    /// The signature or the hash is wrong: the file must not be used.
    Bad(String),
}

/// `rustdesk-1.5.26-x86_64.exe` and `SystemDesk-1.5.26-x86_64.exe` are the same file (releases were renamed once).
fn plain_release_name(name: &str) -> String {
    let lower = name.to_ascii_lowercase();
    let rest = lower
        .strip_prefix("rustdesk-")
        .or_else(|| lower.strip_prefix("systemdesk-"))
        .unwrap_or(&lower);
    match rest.rsplit_once('.') {
        Some((stem, ext)) => format!("{}.{}", stem.strip_suffix("-signed").unwrap_or(stem), ext),
        None => rest.to_owned(),
    }
}

/// The hash the list gives for this file; `None` when the file is not in it or the list names it with two different hashes.
fn listed_hash(sums: &str, file_name: &str) -> Option<String> {
    let want = plain_release_name(file_name);
    let mut found: Option<String> = None;
    for line in sums.lines() {
        let Some((hash, name)) = line.trim().split_once(char::is_whitespace) else {
            continue;
        };
        let name = name.trim().trim_start_matches('*');
        if hash.len() != 64
            || !hash.bytes().all(|b| b.is_ascii_hexdigit())
            || plain_release_name(name) != want
        {
            continue;
        }
        let hash = hash.to_ascii_lowercase();
        match &found {
            Some(other) if *other != hash => return None,
            _ => found = Some(hash),
        }
    }
    found
}

fn signature_is_valid(sums: &[u8], signature_hex: &str, public_key: &[u8; 32]) -> bool {
    use hbb_common::sodiumoxide::crypto::sign;
    let Ok(raw) = hex::decode(signature_hex.trim()) else {
        return false;
    };
    let Ok(signature) = sign::Signature::from_bytes(&raw) else {
        return false;
    };
    sign::verify_detached(&signature, sums, &sign::PublicKey(*public_key))
}

fn sha256_of_file(path: &std::path::Path) -> std::io::Result<String> {
    use sha2::{Digest, Sha256};
    use std::io::Read;
    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hex::encode(hasher.finalize()))
}

/// The whole decision, without the network: is this file the one the signed list promises?
fn verify_release_file(
    sums: &[u8],
    signature_hex: &str,
    public_key: &[u8; 32],
    file_name: &str,
    file_hash: &str,
) -> Result<(), String> {
    if !signature_is_valid(sums, signature_hex, public_key) {
        return Err("the signature of the checksum list is not valid".to_owned());
    }
    let sums = std::str::from_utf8(sums).map_err(|_| "the checksum list is not text".to_owned())?;
    let Some(expected) = listed_hash(sums, file_name) else {
        return Err(format!("{file_name} is not in the signed checksum list"));
    };
    if !expected.eq_ignore_ascii_case(file_hash) {
        return Err(format!("{file_name} does not match the signed checksum"));
    }
    Ok(())
}

fn fetch_small(url: &str) -> Result<Option<Vec<u8>>, String> {
    let client = crate::hbbs_http::create_http_client_with_url_strict(url).map_err(|e| e.to_string())?;
    let response = client.get(url).send().map_err(|e| e.to_string())?;
    if response.status() == reqwest::StatusCode::NOT_FOUND {
        return Ok(None);
    }
    if !response.status().is_success() {
        return Err(format!("HTTP {}", response.status()));
    }
    let bytes = response.bytes().map_err(|e| e.to_string())?;
    if bytes.len() > 256 * 1024 {
        return Err("the answer is too large".to_owned());
    }
    Ok(Some(bytes.to_vec()))
}

/// The checksum list of a release and its signature (`release_dir_url` = .../releases/download/<version>); the error says why not.
fn signed_list(release_dir_url: &str) -> Result<(Vec<u8>, Vec<u8>), String> {
    let sums_url = format!("{}/SHA256SUMS.txt", release_dir_url.trim_end_matches('/'));
    match (fetch_small(&sums_url), fetch_small(&format!("{sums_url}.sig"))) {
        (Ok(Some(sums)), Ok(Some(signature))) => Ok((sums, signature)),
        (Ok(_), Ok(_)) => Err("this release is not signed yet".to_owned()),
        (Err(e), _) | (_, Err(e)) => Err(format!("the signature could not be fetched: {e}")),
    }
}

/// Is the release signed yet? Asked before a big file is downloaded, so an unsigned release costs two small requests, not an installer.
#[allow(dead_code)]
pub fn release_is_signed(release_dir_url: &str) -> DownloadCheck {
    if is_local_test_url(release_dir_url) {
        return DownloadCheck::Good;
    }
    match signed_list(release_dir_url) {
        Ok(_) => DownloadCheck::Good,
        Err(why) => DownloadCheck::NotYet(why),
    }
}

/// Checks a downloaded installer against the signed list of its release.
/// A debug build pointed at a local test server has no signed releases and is not checked.
#[allow(dead_code)]
pub fn check_download(release_dir_url: &str, file: &std::path::Path) -> DownloadCheck {
    if is_local_test_url(release_dir_url) {
        return DownloadCheck::Good;
    }
    let (sums, signature) = match signed_list(release_dir_url) {
        Ok(both) => both,
        Err(why) => return DownloadCheck::NotYet(why),
    };
    let name = file
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or_default()
        .to_owned();
    let hash = match sha256_of_file(file) {
        Ok(h) => h,
        Err(e) => return DownloadCheck::Bad(format!("the file could not be read: {e}")),
    };
    let signature = String::from_utf8_lossy(&signature).into_owned();
    match verify_release_file(&sums, &signature, &RELEASE_SIGNING_PUBLIC_KEY, &name, &hash) {
        Ok(()) => DownloadCheck::Good,
        Err(e) => DownloadCheck::Bad(e),
    }
}

#[cfg(test)]
mod signed_release_tests {
    use super::*;
    use hbb_common::sodiumoxide::crypto::sign;

    const SUMS: &str = "\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  SystemDesk-1.5.26-x86_64.exe
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  SystemDesk-1.5.26-x86_64.msi
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc *SystemDesk-1.5.26-aarch64.dmg
";

    fn keys_and_signature(text: &str) -> ([u8; 32], String) {
        hbb_common::sodiumoxide::init().ok();
        let (pk, sk) = sign::gen_keypair();
        (pk.0, hex::encode(sign::sign_detached(text.as_bytes(), &sk).to_bytes()))
    }

    #[test]
    fn a_good_signature_and_the_listed_hash_pass_under_either_name() {
        let (pk, sig) = keys_and_signature(SUMS);
        let h = "a".repeat(64);
        assert!(verify_release_file(SUMS.as_bytes(), &sig, &pk, "SystemDesk-1.5.26-x86_64.exe", &h).is_ok());
        assert!(verify_release_file(SUMS.as_bytes(), &sig, &pk, "rustdesk-1.5.26-x86_64.exe", &h).is_ok());
        assert!(verify_release_file(SUMS.as_bytes(), &sig, &pk, "rustdesk-1.5.26-aarch64.dmg", &"c".repeat(64)).is_ok());
    }

    #[test]
    fn a_changed_file_a_changed_list_or_another_key_is_refused() {
        let (pk, sig) = keys_and_signature(SUMS);
        let h = "a".repeat(64);
        assert!(verify_release_file(SUMS.as_bytes(), &sig, &pk, "SystemDesk-1.5.26-x86_64.exe", &"d".repeat(64)).is_err());
        let tampered = SUMS.replace("aaaa", "dddd");
        assert!(verify_release_file(tampered.as_bytes(), &sig, &pk, "SystemDesk-1.5.26-x86_64.exe", &h).is_err());
        let (other, _) = keys_and_signature(SUMS);
        assert!(verify_release_file(SUMS.as_bytes(), &sig, &other, "SystemDesk-1.5.26-x86_64.exe", &h).is_err());
        assert!(verify_release_file(SUMS.as_bytes(), "not hex", &pk, "SystemDesk-1.5.26-x86_64.exe", &h).is_err());
        assert!(verify_release_file(SUMS.as_bytes(), &sig[..sig.len() - 2], &pk, "SystemDesk-1.5.26-x86_64.exe", &h).is_err());
        assert!(verify_release_file(SUMS.as_bytes(), "", &pk, "SystemDesk-1.5.26-x86_64.exe", &h).is_err());
    }

    #[test]
    fn a_file_the_list_does_not_name_or_names_twice_with_different_hashes_is_refused() {
        let (pk, sig) = keys_and_signature(SUMS);
        assert!(verify_release_file(SUMS.as_bytes(), &sig, &pk, "SystemDesk-1.5.26-armv7.apk", &"a".repeat(64)).is_err());
        let twice = format!("{SUMS}{}  rustdesk-1.5.26-x86_64.exe\n", "e".repeat(64));
        let (pk2, sig2) = keys_and_signature(&twice);
        assert!(verify_release_file(twice.as_bytes(), &sig2, &pk2, "SystemDesk-1.5.26-x86_64.exe", &"a".repeat(64)).is_err());
    }

    #[test]
    fn the_hash_of_a_file_is_the_sha256_of_its_bytes() {
        let path = std::env::temp_dir().join(format!("sd-sha-test-{}.bin", std::process::id()));
        std::fs::write(&path, b"abc").unwrap();
        assert_eq!(
            sha256_of_file(&path).unwrap(),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn the_embedded_key_has_the_right_length_and_is_not_empty() {
        assert_eq!(RELEASE_SIGNING_PUBLIC_KEY.len(), 32);
        assert!(RELEASE_SIGNING_PUBLIC_KEY.iter().any(|b| *b != 0));
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
