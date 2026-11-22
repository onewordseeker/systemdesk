// SystemDesk: "System information" of the controlled computer, for the person who controls it. It travels with the peer info at connection time (the
// `sd_sysinfo` key of `platform_additions`), so no new message is needed; the owner of the computer can switch it off (`enable-system-info`).
use hbb_common::sysinfo::System;
use serde_json::{json, Value};

pub fn collect() -> Value {
    let mut out = crate::common::get_sysinfo();
    let mut system = System::new();
    system.refresh_memory();
    let free = system.available_memory() as f64 / 1024. / 1024. / 1024.;
    out["memory_free"] = json!(format!("{:.2}GB", free));
    out["arch"] = json!(std::env::consts::ARCH);
    out["app_version"] = json!(crate::VERSION);
    out
}
