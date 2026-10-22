// SystemDesk: when more than one person controls a computer, every controller's pointer is drawn on that computer's screen with the controller's
// name (the "Show my cursor" overlay, which was only an option of view-only sessions), so the controllers can see who is where.
use crate::{
    server::{AuthConnType, AUTHED_CONNS},
    whiteboard,
};
use std::{
    collections::HashSet,
    sync::{
        atomic::{AtomicBool, Ordering},
        Mutex,
    },
};

static LABELS: AtomicBool = AtomicBool::new(false);

lazy_static::lazy_static! {
    // the connections whose overlay this module registered
    static ref DRAWN: Mutex<HashSet<i32>> = Default::default();
    // the connections that asked for their cursor themselves ("Show my cursor"): their overlay stays when the others leave
    static ref ASKED: Mutex<HashSet<i32>> = Default::default();
}

pub fn labels_on() -> bool {
    LABELS.load(Ordering::Relaxed)
}

pub fn asked_for_cursor(conn: i32, asked: bool) {
    if let Ok(mut set) = ASKED.lock() {
        if asked {
            set.insert(conn);
        } else {
            set.remove(&conn);
        }
    }
}

// What to do when the controllers of this computer changed: whether the names are on, which overlays to start, which to stop.
fn plan(
    controllers: usize,
    conns: &[i32],
    drawn: &HashSet<i32>,
    asked: &HashSet<i32>,
) -> (bool, Vec<i32>, Vec<i32>) {
    if controllers >= 2 {
        let start = conns.iter().copied().filter(|c| !drawn.contains(c)).collect();
        (true, start, Vec::new())
    } else {
        let stop = drawn.iter().copied().filter(|c| !asked.contains(c)).collect();
        (false, Vec::new(), stop)
    }
}

pub fn refresh() {
    let (controllers, conns) = {
        let Ok(authed) = AUTHED_CONNS.lock() else {
            return;
        };
        let remote = authed
            .iter()
            .filter(|c| c.conn_type == AuthConnType::Remote)
            .collect::<Vec<_>>();
        let people = remote.iter().map(|c| &c.session_key).collect::<HashSet<_>>();
        (people.len(), remote.iter().map(|c| c.conn_id).collect::<Vec<_>>())
    };
    let (Ok(mut drawn), Ok(asked)) = (DRAWN.lock(), ASKED.lock()) else {
        return;
    };
    let (labels, start, stop) = plan(controllers, &conns, &drawn, &asked);
    LABELS.store(labels, Ordering::Relaxed);
    for conn in start {
        whiteboard::register_whiteboard(whiteboard::get_key_cursor(conn));
        drawn.insert(conn);
    }
    for conn in stop {
        whiteboard::unregister_whiteboard(whiteboard::get_key_cursor(conn));
        drawn.remove(&conn);
    }
}

pub fn left(conn: i32) {
    if let Ok(mut set) = DRAWN.lock() {
        set.remove(&conn);
    }
    asked_for_cursor(conn, false);
    refresh();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn set(ids: &[i32]) -> HashSet<i32> {
        ids.iter().copied().collect()
    }

    #[test]
    fn a_single_controller_gets_no_labels() {
        let (on, start, stop) = plan(1, &[7], &set(&[]), &set(&[]));
        assert!(!on);
        assert!(start.is_empty() && stop.is_empty());
    }

    #[test]
    fn the_second_controller_turns_the_labels_on_for_everyone() {
        let (on, mut start, stop) = plan(2, &[7, 8], &set(&[]), &set(&[]));
        start.sort();
        assert!(on);
        assert_eq!(start, vec![7, 8]);
        assert!(stop.is_empty());
    }

    #[test]
    fn a_controller_already_drawn_is_not_started_twice() {
        let (_, start, _) = plan(2, &[7, 8], &set(&[7]), &set(&[]));
        assert_eq!(start, vec![8]);
    }

    #[test]
    fn when_the_others_leave_the_overlay_goes_except_for_who_asked_for_it() {
        let (on, start, mut stop) = plan(1, &[7], &set(&[7, 8]), &set(&[]));
        stop.sort();
        assert!(!on);
        assert!(start.is_empty());
        assert_eq!(stop, vec![7, 8]);

        let (_, _, stop) = plan(1, &[7], &set(&[7, 8]), &set(&[7]));
        assert_eq!(stop, vec![8], "a controller that asked for its cursor keeps it");
    }

    #[test]
    fn a_reconnecting_controller_is_one_person() {
        // two connections of one session key count as one controller (the caller counts people, not connections)
        let (on, _, _) = plan(1, &[7, 9], &set(&[]), &set(&[]));
        assert!(!on);
    }
}
