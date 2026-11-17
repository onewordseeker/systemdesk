// SystemDesk: the Windows service replaces the server when the active Windows session changes (a sign-in, a lock screen, Remote
// Desktop). The viewers are told first, so they reconnect quietly and land on the new session's screen instead of meeting an error.
use hbb_common::tokio::sync::watch;

/// The close reason sent to every viewer. A controller that does not know it shows it as an ordinary error and reconnects by itself.
pub const REASON: &str = "The remote session is changing. Reconnecting...";

lazy_static::lazy_static! {
    static ref SWITCH: watch::Sender<bool> = watch::channel(false).0;
}

/// Resolves `changed()` once `announce` has been called after this receiver was made.
pub fn subscribe() -> watch::Receiver<bool> {
    SWITCH.subscribe()
}

#[cfg(windows)]
pub fn announce() {
    SWITCH.send_replace(true);
}

#[cfg(all(test, windows))]
mod tests {
    use super::*;
    use hbb_common::tokio::{self, time::Duration};

    #[tokio::test]
    async fn a_viewer_hears_the_announcement() {
        let mut rx = subscribe();
        announce();
        tokio::time::timeout(Duration::from_secs(1), rx.changed())
            .await
            .unwrap()
            .unwrap();
    }

    #[test]
    fn an_older_controller_reconnects_by_itself() {
        assert!(crate::client::check_if_retry(
            "error",
            "Connection Error",
            REASON,
            false
        ));
    }
}
