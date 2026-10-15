// SystemDesk: the ticket the relay asks for.
//
// The relay refuses every connection that does not carry a ticket from the SystemDesk API. The Flutter side gets the ticket together
// with the license session and keeps it in the local option `sd_ticket:<host id>` (a new one with every heartbeat, a ticket is only good
// for 90 seconds). Here it is picked up right before the connection starts and sent in the `token` field of the connection request.
//   "-"   = this session has no ticket (the server does not hand them out): do not wait for one
//   ""    = not there yet: the license session is still being started, wait for it
use hbb_common::{
    base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _},
    config::LocalConfig,
    tokio,
};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const WAIT: Duration = Duration::from_secs(6);
const STEP: Duration = Duration::from_millis(100);

fn option_key(peer: &str) -> String {
    let id = peer
        .split('@')
        .next()
        .unwrap_or(peer)
        .split(',')
        .next()
        .unwrap_or(peer)
        .replace(' ', "");
    format!("sd_ticket:{}", id)
}

// seconds since 1970 until which the ticket may be used, read from its (signed) payload
fn expires_at(ticket: &str) -> Option<u64> {
    let payload = URL_SAFE_NO_PAD.decode(ticket.split('.').next()?).ok()?;
    serde_json::from_slice::<serde_json::Value>(&payload)
        .ok()?
        .get("exp")?
        .as_u64()
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or_default()
}

// The `token` for a connection to `peer`: the relay ticket when the license session has one, else what was used before.
pub async fn token_for(peer: &str) -> String {
    let fallback = LocalConfig::get_option("access_token");
    let key = option_key(peer);
    let started = std::time::Instant::now();
    loop {
        let v = LocalConfig::get_option(&key);
        if v == "-" {
            return fallback;
        }
        if !v.is_empty() && expires_at(&v).map_or(false, |e| e > now() + 3) {
            return v;
        }
        if started.elapsed() >= WAIT {
            return if v.is_empty() { fallback } else { v };
        }
        tokio::time::sleep(STEP).await;
    }
}
