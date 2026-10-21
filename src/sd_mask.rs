#![allow(dead_code)]
// The small blob that carries the servers of a build (see sd_servers.rs) is not readable text: the build script scrambles it with `seal`, the
// program unscrambles it with `open`. This file is shared by build.rs and the program (`#[path]`), so both always agree.
// It keeps the server names and the key out of the program file and out of anything that is read with a text search. It is NOT encryption
// that could withstand someone who runs the program: the program has to know the servers to use them.
const K_STREAM: u64 = 0x5D1E_5C0A_9B3F_7A21;
const K_SEED: u64 = 0xA7C1_93D2_4E58_B60F;

fn next(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

fn check(plain: &[u8]) -> u32 {
    let mut h: u64 = 0xCBF2_9CE4_8422_2325;
    for b in plain {
        h = (h ^ u64::from(*b)).wrapping_mul(0x0000_0100_0000_01B3);
    }
    (h >> 32) as u32
}

fn apply_stream(bytes: &mut [u8], seed: u64) {
    let mut state = seed ^ K_STREAM;
    let mut block = [0u8; 8];
    for (i, b) in bytes.iter_mut().enumerate() {
        if i % 8 == 0 {
            block = next(&mut state).to_le_bytes();
        }
        *b ^= block[i % 8];
    }
}

/// seed (8 bytes, disguised) + the bytes scrambled with a stream made from the seed + a 4-byte check of the plain bytes.
pub fn seal(plain: &[u8], seed: u64) -> Vec<u8> {
    let mut out = Vec::with_capacity(plain.len() + 12);
    out.extend_from_slice(&(seed ^ K_SEED).to_le_bytes());
    let mut body = plain.to_vec();
    apply_stream(&mut body, seed);
    out.extend_from_slice(&body);
    out.extend_from_slice(&check(plain).to_le_bytes());
    out
}

/// The plain bytes of what `seal` made, or None when it is not a sealed blob (empty, cut, changed).
pub fn open(sealed: &[u8]) -> Option<Vec<u8>> {
    if sealed.len() < 12 {
        return None;
    }
    let seed = u64::from_le_bytes(sealed[..8].try_into().ok()?) ^ K_SEED;
    let (body, tail) = sealed[8..].split_at(sealed.len() - 12);
    let mut plain = body.to_vec();
    apply_stream(&mut plain, seed);
    (check(&plain).to_le_bytes() == tail).then_some(plain)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn what_is_sealed_opens_again() {
        let plain = br#"{"id":"id.example.net:21116","key":"abc="}"#;
        for seed in [0u64, 1, 0xDEAD_BEEF_CAFE_F00D, u64::MAX] {
            let sealed = seal(plain, seed);
            assert_eq!(open(&sealed).as_deref(), Some(&plain[..]), "seed {seed}");
        }
    }

    #[test]
    fn a_sealed_blob_has_no_readable_text_and_differs_per_seed() {
        let plain = b"server.relay.example.net";
        let a = seal(plain, 1);
        let b = seal(plain, 2);
        assert_ne!(a, b);
        assert!(!a.windows(6).any(|w| w == b"server"));
        assert!(!b.windows(6).any(|w| w == b"relay."));
    }

    #[test]
    fn rubbish_does_not_open() {
        assert_eq!(open(&[]), None);
        assert_eq!(open(&[1, 2, 3]), None);
        let mut sealed = seal(b"hello world", 7);
        sealed[10] ^= 1;
        assert_eq!(open(&sealed), None);
        let cut = &seal(b"hello world", 7)[..15];
        assert_eq!(open(cut), None);
    }
}
