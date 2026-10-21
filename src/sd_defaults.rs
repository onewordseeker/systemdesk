// SystemDesk: the default of a few display options, for a person who has not chosen one yet. A choice that was made (in Settings, or per
// computer) always wins, and so does a default the client's own configuration already set.
use hbb_common::config::{keys, DEFAULT_DISPLAY_SETTINGS};

/// "Scale adaptive" (the remote screen fits the window) is the default view style, not "Scale original".
pub fn apply() {
    DEFAULT_DISPLAY_SETTINGS
        .write()
        .unwrap()
        .entry(keys::OPTION_VIEW_STYLE.to_owned())
        .or_insert_with(|| "adaptive".to_owned());
}

#[cfg(test)]
mod tests {
    use super::*;
    use hbb_common::config::UserDefaultConfig;

    #[test]
    fn the_default_view_style_is_adaptive_and_an_earlier_default_is_kept() {
        // nobody has chosen yet: adaptive (a saved choice is read before this default, see hbb_common's get_or)
        DEFAULT_DISPLAY_SETTINGS.write().unwrap().remove(keys::OPTION_VIEW_STYLE);
        apply();
        assert_eq!(UserDefaultConfig::default().get(keys::OPTION_VIEW_STYLE), "adaptive");
        // a default that was set before (the client's own configuration) is not replaced
        DEFAULT_DISPLAY_SETTINGS
            .write()
            .unwrap()
            .insert(keys::OPTION_VIEW_STYLE.to_owned(), "original".to_owned());
        apply();
        assert_eq!(
            DEFAULT_DISPLAY_SETTINGS.read().unwrap().get(keys::OPTION_VIEW_STYLE).map(String::as_str),
            Some("original")
        );
        DEFAULT_DISPLAY_SETTINGS.write().unwrap().remove(keys::OPTION_VIEW_STYLE);
    }
}
