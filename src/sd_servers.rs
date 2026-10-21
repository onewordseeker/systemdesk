// SystemDesk: the servers are part of the program, not of a setting. The ID server, the relay, the API server and the server key of a build are
// given to the build (build.rs: SD_PROFILE), come out of it scrambled (sd_mask.rs) and are put in force when the program starts, over
// whatever was saved before. The person cannot see or change them: the Network tab has no "ID/Relay Server" entry, a server typed into an
// older config is ignored, and nothing readable is left in the program file.
//
// A test build carries the test servers, a production build the production servers (the profile names its channel, and the build refuses a
// profile of the other channel). Not active in debug builds: the developer's launcher points a debug app at a local or test server.
use base::config::keys;
use hbb_common::{
    config::{BUILTIN_SETTINGS, OVERWRITE_SETTINGS, PROD_RENDEZVOUS_SERVER},
    log,
};

static BLOB: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/sd_profile.bin"));

#[derive(Debug, PartialEq, Eq)]
pub struct Profile {
    pub id: String,
    pub relay: String,
    pub api: String,
    pub key: String,
}

fn decode(blob: &[u8], channel: &str) -> Option<Profile> {
    let plain = crate::sd_mask::open(blob)?;
    let v: serde_json::Value = serde_json::from_slice(&plain).ok()?;
    let text = |k: &str| v.get(k).and_then(|x| x.as_str()).unwrap_or_default().trim().to_owned();
    if text("channel") != channel {
        return None;
    }
    let p = Profile { id: text("id"), relay: text("relay"), api: text("api"), key: text("key") };
    // only our own servers, over https for the API: whatever the blob says, the app talks to systemdesk.net and nothing else
    let ok = !p.id.is_empty()
        && crate::sd_lock::is_ours(&p.id)
        && (p.relay.is_empty() || crate::sd_lock::is_ours(&p.relay))
        && p.api.starts_with("https://")
        && crate::sd_lock::is_ours(&p.api)
        && !p.key.is_empty();
    ok.then_some(p)
}

/// The servers this build carries, or None (a developer's build without them, or a blob that does not fit this channel).
pub fn profile() -> Option<Profile> {
    decode(BLOB, crate::sd_update::update_channel())
}

/// Puts the servers in force. Called at start-up of every process (core_main and the Flutter init), so the service, the tray and the window all
/// agree. Idempotent.
pub fn apply() {
    if !crate::sd_lock::active() {
        return;
    }
    let Some(p) = profile() else {
        log::error!("SystemDesk: this build carries no valid server profile");
        return;
    };
    put_in_force(p);
}

fn put_in_force(p: Profile) {
    {
        let mut o = OVERWRITE_SETTINGS.write().unwrap();
        o.insert("custom-rendezvous-server".to_owned(), p.id.clone());
        // empty = no forced relay: the ID server hands out the relay (and a host's own relay wins)
        o.insert("relay-server".to_owned(), p.relay);
        o.insert("api-server".to_owned(), p.api);
        o.insert("key".to_owned(), p.key);
    }
    *PROD_RENDEZVOUS_SERVER.write().unwrap() = p.id;
    BUILTIN_SETTINGS
        .write()
        .unwrap()
        .insert(keys::OPTION_HIDE_SERVER_SETTINGS.to_owned(), "Y".to_owned());
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sealed(json: &str) -> Vec<u8> {
        crate::sd_mask::seal(json.as_bytes(), 0x1234_5678_9ABC_DEF0)
    }

    const OK: &str = r#"{"channel":"stable","id":"id.systemdesk.net:21116","relay":"","api":"https://api.systemdesk.net","key":"K3y="}"#;

    #[test]
    fn a_profile_of_this_channel_is_read() {
        let p = decode(&sealed(OK), "stable").unwrap();
        assert_eq!(p.id, "id.systemdesk.net:21116");
        assert_eq!(p.relay, "");
        assert_eq!(p.api, "https://api.systemdesk.net");
        assert_eq!(p.key, "K3y=");
    }

    #[test]
    fn the_servers_of_the_build_are_in_force_and_the_entry_is_hidden() {
        use hbb_common::config::Config;
        // (read only: nothing is saved by this test, so the developer's own copy of the app keeps its settings; a saved value never beats
        // these because OVERWRITE_SETTINGS is read first, see hbb_common's get_or)
        put_in_force(decode(&sealed(OK), "stable").unwrap());
        assert_eq!(Config::get_option("custom-rendezvous-server"), "id.systemdesk.net:21116");
        assert_eq!(Config::get_option("api-server"), "https://api.systemdesk.net");
        assert_eq!(Config::get_option("key"), "K3y=");
        assert_eq!(Config::get_option("relay-server"), "");
        assert_eq!(Config::get_rendezvous_server(), "id.systemdesk.net:21116");
        assert_eq!(crate::common::get_builtin_option(keys::OPTION_HIDE_SERVER_SETTINGS), "Y");
    }

    #[test]
    fn a_profile_of_the_other_channel_is_not() {
        assert_eq!(decode(&sealed(OK), "test"), None);
    }

    #[test]
    fn only_our_servers_over_https_are_accepted() {
        for bad in [
            r#"{"channel":"stable","id":"evil.example:21116","relay":"","api":"https://api.systemdesk.net","key":"k"}"#,
            r#"{"channel":"stable","id":"id.systemdesk.net","relay":"relay.evil.example","api":"https://api.systemdesk.net","key":"k"}"#,
            r#"{"channel":"stable","id":"id.systemdesk.net","relay":"","api":"http://api.systemdesk.net","key":"k"}"#,
            r#"{"channel":"stable","id":"id.systemdesk.net","relay":"","api":"https://api.evil.example","key":"k"}"#,
            r#"{"channel":"stable","id":"id.systemdesk.net","relay":"","api":"https://api.systemdesk.net","key":""}"#,
            r#"{"channel":"stable","id":"","relay":"","api":"https://api.systemdesk.net","key":"k"}"#,
            "not json",
        ] {
            assert_eq!(decode(&sealed(bad), "stable"), None, "{bad}");
        }
    }

    #[test]
    fn an_empty_or_damaged_blob_is_no_profile() {
        assert_eq!(decode(&[], "stable"), None);
        let mut b = sealed(OK);
        b[12] ^= 0xFF;
        assert_eq!(decode(&b, "stable"), None);
    }

    // When the tests are built with SD_PROFILE (like the CI build), the blob that is really in the program must read back.
    #[test]
    fn the_blob_built_into_the_program_reads_back_when_there_is_one() {
        if BLOB.is_empty() {
            return;
        }
        let p = profile().expect("the build carries a profile that does not fit its channel or our servers");
        assert!(crate::sd_lock::is_ours(&p.id) && crate::sd_lock::is_ours(&p.api));
        let needle = &p.id.as_bytes()[..p.id.len().min(8)];
        assert!(!BLOB.windows(needle.len()).any(|w| w == needle), "the server name is readable in the blob");
    }
}
