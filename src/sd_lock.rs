// SystemDesk talks to systemdesk.net and to nothing else: the ID, relay and API servers can only be ours, and the WebRTC transport (which asks
// Google's and Cloudflare's STUN servers) stays off. A saved server that is not ours (left over from an older install, typed by hand,
// imported) is cleared at start-up; the app then falls back to its built-in systemdesk.net servers.
//
// Not active in debug builds: the developer's launcher points a debug app at a local or test server.
use hbb_common::{config::Config, log};

const SERVER_OPTIONS: [&str; 3] = ["custom-rendezvous-server", "relay-server", "api-server"];

pub fn active() -> bool {
    !cfg!(debug_assertions) && crate::sd_update::updates_enabled()
}

// "https://user@Host.example:21114/path" -> "host.example"
fn host_of(value: &str) -> String {
    let v = value.trim();
    let v = v.split_once("://").map_or(v, |(_, rest)| rest);
    let authority = v.split(|c| c == '/' || c == '?' || c == '#').next().unwrap_or_default();
    let authority = authority.rsplit('@').next().unwrap_or_default();
    let host = if let Some(rest) = authority.strip_prefix('[') {
        rest.split(']').next().unwrap_or_default()
    } else {
        authority.split(':').next().unwrap_or_default()
    };
    host.trim_end_matches('.').to_ascii_lowercase()
}

pub fn is_ours(value: &str) -> bool {
    let host = host_of(value);
    host == "systemdesk.net" || host.ends_with(".systemdesk.net")
}

pub fn sanitize_server_options() {
    if !active() {
        return;
    }
    for key in SERVER_OPTIONS {
        let value = Config::get_option(key);
        if !value.is_empty() && !is_ours(&value) {
            log::warn!("SystemDesk: the saved {} is not a systemdesk.net server, it is cleared", key);
            Config::set_option(key.to_owned(), String::new());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn our_servers_are_ours() {
        for ok in [
            "server.relay.systemdesk.net",
            "server.relay.systemdesk.net:21116",
            "r3f9a21c07b.relay.test.systemdesk.net:22117",
            "http://server.relay.systemdesk.net:21114",
            "https://test.api.systemdesk.net",
            "https://prod.api.systemdesk.net/api/health",
            "HTTPS://Prod.API.SystemDesk.NET",
            "systemdesk.net",
            "server.relay.systemdesk.net.",
        ] {
            assert!(is_ours(ok), "{ok}");
        }
    }

    #[test]
    fn everything_else_is_not() {
        for bad in [
            "",
            "72.62.66.94",
            "72.62.66.94:21116",
            "rustdesk.hamidentifier.cloud",
            "rustdesk.hamidentifier.cloud:21116",
            "http://rustdesk.hamidentifier.cloud:21114",
            "rs-ny.rustdesk.com",
            "systemdesk.net.evil.test",
            "evilsystemdesk.net",
            "notsystemdesk.net:21116",
            "https://systemdesk.net@evil.test/",
            "https://evil.test/systemdesk.net",
            "https://evil.test?x=.systemdesk.net",
            "[::1]:21116",
            "localhost:3000",
            "http://127.0.0.1:3000",
        ] {
            assert!(!is_ours(bad), "{bad}");
        }
    }

    #[test]
    fn the_host_is_read_out_of_any_form_of_address() {
        assert_eq!(host_of(" http://User:pw@Host.Example:21114/x?y#z "), "host.example");
        assert_eq!(host_of("[2001:db8::1]:21116"), "2001:db8::1");
        assert_eq!(host_of("host.example"), "host.example");
    }
}
