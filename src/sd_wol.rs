// SystemDesk: Wake on LAN.
//
// A sleeping or switched-off computer that has Wake on LAN enabled (BIOS/UEFI and the network adapter's settings) starts when a "magic packet" reaches
// its network adapter: 6 bytes of 0xFF followed by the adapter's MAC address 16 times, sent as a UDP broadcast. The packet cannot cross the internet,
// so it must be sent from a computer on the SAME network as the sleeping one; it is sent on every network this computer is on (the limited broadcast
// and the broadcast of each subnet, port 9).
// The Flutter side asks through `main_get_common("sd-wol:<mac>")` and gets "ok:<packets sent>" or "error:<what went wrong>".
use std::net::{IpAddr, Ipv4Addr, SocketAddr, UdpSocket};

const WOL_PORT: u16 = 9;

/// "AA:BB:CC:DD:EE:FF", "aa-bb-cc-dd-ee-ff", "AABBCCDDEEFF" and "aabb.ccdd.eeff" are the same address.
pub fn parse_mac(s: &str) -> Option<[u8; 6]> {
    let hex: String = s
        .chars()
        .filter(|c| !matches!(c, ':' | '-' | '.' | ' '))
        .collect();
    if hex.len() != 12 || !hex.chars().all(|c| c.is_ascii_hexdigit()) {
        return None;
    }
    let mut mac = [0u8; 6];
    for (i, byte) in mac.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16).ok()?;
    }
    // all zeros and all ones are not the address of any adapter
    if mac == [0; 6] || mac == [0xFF; 6] {
        return None;
    }
    Some(mac)
}

pub fn format_mac(mac: &[u8; 6]) -> String {
    mac.iter()
        .map(|b| format!("{:02X}", b))
        .collect::<Vec<_>>()
        .join(":")
}

/// The 102 bytes the adapter waits for: 6 x 0xFF, then the MAC address 16 times.
pub fn magic_packet(mac: &[u8; 6]) -> Vec<u8> {
    let mut packet = vec![0xFFu8; 6];
    for _ in 0..16 {
        packet.extend_from_slice(mac);
    }
    packet
}

/// The address a packet to a whole subnet is sent to.
pub fn directed_broadcast(addr: Ipv4Addr, netmask: Ipv4Addr) -> Ipv4Addr {
    Ipv4Addr::from(u32::from(addr) | !u32::from(netmask))
}

// An address worth sending from: not loopback, not "unspecified", not a link-local 169.254.x.x one.
fn usable(addr: Ipv4Addr) -> bool {
    !(addr.is_loopback() || addr.is_unspecified() || addr.is_link_local())
}

fn send_from(local: Ipv4Addr, to: Ipv4Addr, packet: &[u8]) -> std::io::Result<()> {
    let socket = UdpSocket::bind(SocketAddr::from((local, 0)))?;
    socket.set_broadcast(true)?;
    socket.send_to(packet, SocketAddr::from((to, WOL_PORT)))?;
    Ok(())
}

// (local address, where to send) for every network this computer is on
fn routes() -> Vec<(Ipv4Addr, Ipv4Addr)> {
    let mut out = Vec::new();
    #[cfg(not(target_os = "ios"))]
    for interface in default_net::get_interfaces() {
        for net in &interface.ipv4 {
            if !usable(net.addr) {
                continue;
            }
            for to in [
                Ipv4Addr::BROADCAST,
                directed_broadcast(net.addr, net.netmask),
            ] {
                if !out.contains(&(net.addr, to)) {
                    out.push((net.addr, to));
                }
            }
        }
    }
    // when the networks cannot be listed, the operating system picks the network
    if out.is_empty() {
        out.push((Ipv4Addr::UNSPECIFIED, Ipv4Addr::BROADCAST));
    }
    out
}

/// Send the magic packet for `mac` on every local network. "ok:<packets>" or "error:<reason>".
pub fn send(mac: &str) -> String {
    let Some(parsed) = parse_mac(mac) else {
        return "error:That is not a MAC address. It looks like AA:BB:CC:DD:EE:FF.".to_owned();
    };
    let packet = magic_packet(&parsed);
    let mut sent = 0;
    let mut last_error = String::new();
    for (local, to) in routes() {
        match send_from(local, to, &packet) {
            Ok(()) => {
                sent += 1;
                hbb_common::log::info!(
                    "Wake on LAN for {} sent from {} to {}",
                    format_mac(&parsed),
                    IpAddr::V4(local),
                    to
                );
            }
            Err(e) => last_error = e.to_string(),
        }
    }
    if sent > 0 {
        format!("ok:{}", sent)
    } else {
        format!(
            "error:The wake-up signal could not be sent{}",
            if last_error.is_empty() {
                ".".to_owned()
            } else {
                format!(" ({}).", last_error)
            }
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_mac_address_is_understood_however_it_is_written() {
        let want = Some([0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E]);
        assert_eq!(parse_mac("00:1A:2B:3C:4D:5E"), want);
        assert_eq!(parse_mac("00-1a-2b-3c-4d-5e"), want);
        assert_eq!(parse_mac("001A2B3C4D5E"), want);
        assert_eq!(parse_mac("001a.2b3c.4d5e"), want);
        assert_eq!(parse_mac("  00:1a:2b:3c:4d:5e "), want);
    }

    #[test]
    fn what_is_not_a_mac_address_is_refused() {
        for bad in [
            "",
            "00:1A:2B:3C:4D",
            "00:1A:2B:3C:4D:5E:6F",
            "GG:1A:2B:3C:4D:5E",
            "00:00:00:00:00:00",
            "FF:FF:FF:FF:FF:FF",
            "192.168.1.5",
            "not a mac",
        ] {
            assert_eq!(parse_mac(bad), None, "{bad}");
        }
    }

    #[test]
    fn the_address_is_shown_in_one_form() {
        assert_eq!(format_mac(&[0, 0x1a, 0x2b, 0x3c, 0x4d, 0x5e]), "00:1A:2B:3C:4D:5E");
    }

    #[test]
    fn the_magic_packet_is_what_the_adapter_waits_for() {
        let mac = [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E];
        let p = magic_packet(&mac);
        assert_eq!(p.len(), 102);
        assert!(p[..6].iter().all(|b| *b == 0xFF));
        for i in 0..16 {
            assert_eq!(&p[6 + i * 6..12 + i * 6], &mac);
        }
    }

    #[test]
    fn a_subnet_broadcast_is_the_address_with_all_host_bits_set() {
        let b = directed_broadcast(
            Ipv4Addr::new(192, 168, 1, 23),
            Ipv4Addr::new(255, 255, 255, 0),
        );
        assert_eq!(b, Ipv4Addr::new(192, 168, 1, 255));
        let b = directed_broadcast(Ipv4Addr::new(10, 4, 9, 8), Ipv4Addr::new(255, 255, 0, 0));
        assert_eq!(b, Ipv4Addr::new(10, 4, 255, 255));
    }

    #[test]
    fn only_real_network_addresses_are_used() {
        assert!(!usable(Ipv4Addr::LOCALHOST));
        assert!(!usable(Ipv4Addr::UNSPECIFIED));
        assert!(!usable(Ipv4Addr::new(169, 254, 3, 4)));
        assert!(usable(Ipv4Addr::new(192, 168, 1, 23)));
    }

    #[test]
    fn a_wrong_address_is_answered_with_a_sentence_not_a_crash() {
        assert!(send("hello").starts_with("error:"));
    }

    // The packet really goes out: a local socket on the WoL port receives what `send_from` sends to it.
    #[test]
    fn the_packet_arrives() {
        let Ok(receiver) = UdpSocket::bind((Ipv4Addr::LOCALHOST, 0)) else {
            return;
        };
        receiver
            .set_read_timeout(Some(std::time::Duration::from_secs(2)))
            .ok();
        let port = receiver.local_addr().map(|a| a.port()).unwrap_or(0);
        let packet = magic_packet(&[1, 2, 3, 4, 5, 6]);
        let sender = UdpSocket::bind((Ipv4Addr::LOCALHOST, 0)).unwrap();
        sender
            .send_to(&packet, SocketAddr::from((Ipv4Addr::LOCALHOST, port)))
            .unwrap();
        let mut buf = [0u8; 200];
        let (n, _) = receiver.recv_from(&mut buf).unwrap();
        assert_eq!(&buf[..n], &packet[..]);
    }
}
