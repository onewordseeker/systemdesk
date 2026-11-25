// SystemDesk: what this app tells the licence server when it registers a device (POST /api/devices/register).
//
// The server wants the machine's details (version, system, processor, memory, user) and a signature of the request, so a script that only
// knows the address cannot fill the device list with empty devices. The signature is HMAC-SHA256 over
//   "SD-REG-V1 \n timestamp \n nonce \n hardware_fingerprint \n platform \n rustdesk_id \n rustdesk_uuid"
// with a key that is compiled in (SD_REG_KEY, a build secret, not in the source). A key inside an app stops scripts and replays, not somebody
// who takes the app apart. A build without the key sends no signature and the server decides what that means (it only counts it as a flag).
use sha2::{Digest, Sha256};

fn key() -> Option<&'static str> {
    option_env!("SD_REG_KEY").map(str::trim).filter(|k| !k.is_empty())
}

fn hmac_sha256(key: &[u8], message: &[u8]) -> [u8; 32] {
    let mut block = [0u8; 64];
    if key.len() > block.len() {
        block[..32].copy_from_slice(&Sha256::digest(key));
    } else {
        block[..key.len()].copy_from_slice(key);
    }
    let mut inner = Sha256::new();
    inner.update(block.map(|b| b ^ 0x36));
    inner.update(message);
    let mut outer = Sha256::new();
    outer.update(block.map(|b| b ^ 0x5c));
    outer.update(inner.finalize());
    outer.finalize().into()
}

fn sign_with(key: &str, fields: &str) -> String {
    let parts: Vec<&str> = fields.split('|').collect();
    if parts.len() != 6 {
        return String::new();
    }
    let canonical = format!(
        "SD-REG-V1\n{}\n{}\n{}\n{}\n{}\n{}",
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]
    );
    hex::encode(hmac_sha256(key.as_bytes(), canonical.as_bytes()))
}

/// "timestamp|nonce|hardware_fingerprint|platform|rustdesk_id|rustdesk_uuid" -> the signature (hex), or "" when this build has no key.
pub fn sign(fields: &str) -> String {
    match key() {
        Some(k) => sign_with(k, fields),
        None => String::new(),
    }
}

/// The machine's details as the registration sends them (JSON).
pub fn info() -> String {
    let mut out = crate::common::get_sysinfo();
    out["version"] = serde_json::json!(crate::VERSION);
    out.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hmac_sha256_matches_the_published_test_vector() {
        // RFC 4231, test case 2
        assert_eq!(
            hex::encode(hmac_sha256(b"Jefe", b"what do ya want for nothing?")),
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
        );
    }

    #[test]
    fn a_long_key_is_hashed_first_like_the_standard_says() {
        // RFC 4231, test case 6: a 131-byte key
        let key = [0xaau8; 131];
        assert_eq!(
            hex::encode(hmac_sha256(&key, b"Test Using Larger Than Block-Size Key - Hash Key First")),
            "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
        );
    }

    #[test]
    fn the_signature_is_the_one_the_server_checks() {
        // computed with node's crypto.createHmac over the same text (the server: services/device_registration.js)
        let fields = format!("1700000000|00112233aabbccdd|{}|windows|123456789|uuid-abc", "f".repeat(64));
        assert_eq!(
            sign_with("unit-test-key", &fields),
            "a5eb60b5a2ce36dddca956ed6d14df093051985dec652350a0b6a5b9e1218fe1"
        );
    }

    #[test]
    fn a_request_with_the_wrong_number_of_fields_is_not_signed() {
        assert_eq!(sign_with("k", "only|three|fields"), "");
        assert_eq!(sign_with("k", ""), "");
    }
}
