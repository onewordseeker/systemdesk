// SystemDesk: key exchange version 2, TLS 1.3 between the two computers (see docs/security/tls-handshake-design.md).
//
// It runs on the same byte stream as before, through the relay or direct, so the relay still only passes bytes. There is no certificate
// authority: each computer presents the public half of its own identity key (a raw public key, RFC 7250) and the controller accepts it
// only when it is the key the ID server signed for the ID it asked for, the same check the older exchange makes. The controller needs no
// certificate of its own; it proves itself at the application layer with the password, the approval or the second factor.
use base::message_proto::{message, Message, PublicKey};
use hbb_common::{
    anyhow::anyhow,
    bail,
    config::CONNECT_TIMEOUT,
    protobuf::Message as _,
    tcp::KX_VERSION_TLS,
    timeout,
    tokio_rustls::rustls::{
        self,
        client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier},
        crypto::{
            ring::{
                cipher_suite::{TLS13_AES_256_GCM_SHA384, TLS13_CHACHA20_POLY1305_SHA256},
                default_provider,
                sign::any_eddsa_type,
            },
            verify_tls13_signature_with_raw_key, CryptoProvider, WebPkiSupportedAlgorithms,
        },
        pki_types::{
            CertificateDer, PrivatePkcs8KeyDer, ServerName, SubjectPublicKeyInfoDer, UnixTime,
        },
        server::AlwaysResolvesServerRawPublicKeys,
        sign::CertifiedKey,
        CertificateError, DigitallySignedStruct, SignatureScheme,
    },
    ResultType, Stream,
};
use std::sync::Arc;

const ED25519_SPKI_PREFIX: [u8; 12] = [
    0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00,
];
const ED25519_PKCS8_PREFIX: [u8; 16] = [
    0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
];

fn spki(pk: &[u8]) -> Vec<u8> {
    let mut der = ED25519_SPKI_PREFIX.to_vec();
    der.extend_from_slice(pk);
    der
}

// TLS 1.3 only, and only the two suites the panel can name: AES-256-GCM first, ChaCha20-Poly1305 for phones without AES hardware.
fn provider() -> Arc<CryptoProvider> {
    let mut provider = default_provider();
    provider.cipher_suites = vec![TLS13_AES_256_GCM_SHA384, TLS13_CHACHA20_POLY1305_SHA256];
    Arc::new(provider)
}

#[derive(Debug)]
struct PinnedKey {
    spki: Vec<u8>,
    algs: WebPkiSupportedAlgorithms,
}

impl ServerCertVerifier for PinnedKey {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        if intermediates.is_empty() && end_entity.as_ref() == self.spki.as_slice() {
            Ok(ServerCertVerified::assertion())
        } else {
            Err(rustls::Error::InvalidCertificate(
                CertificateError::ApplicationVerificationFailure,
            ))
        }
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        Err(rustls::Error::General("TLS 1.2 is not used".to_owned()))
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        verify_tls13_signature_with_raw_key(
            message,
            &SubjectPublicKeyInfoDer::from(cert.as_ref()),
            dss,
            &self.algs,
        )
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algs.supported_schemes()
    }

    fn requires_raw_public_keys(&self) -> bool {
        true
    }
}

/// The controller's side: accepts only the host whose identity key is `host_pk`.
fn client_config(host_pk: &[u8]) -> ResultType<Arc<rustls::ClientConfig>> {
    let provider = provider();
    let verifier = PinnedKey {
        spki: spki(host_pk),
        algs: provider.signature_verification_algorithms,
    };
    let mut config = rustls::ClientConfig::builder_with_provider(provider)
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(verifier))
        .with_no_client_auth();
    config.resumption = rustls::client::Resumption::disabled();
    Ok(Arc::new(config))
}

/// The host's side: presents the identity key pair (`sk` is the 32 byte seed followed by the public key, as sodium stores it).
fn server_config(sk: &[u8], pk: &[u8]) -> ResultType<Arc<rustls::ServerConfig>> {
    if sk.len() != 64 || pk.len() != 32 {
        bail!("the identity key pair has the wrong length");
    }
    let mut der = ED25519_PKCS8_PREFIX.to_vec();
    der.extend_from_slice(&sk[..32]);
    let key = any_eddsa_type(&PrivatePkcs8KeyDer::from(der))?;
    let public = spki(pk);
    if key.public_key().as_ref().map(|k| k.as_ref()) != Some(public.as_slice()) {
        bail!("the identity key pair does not match its public key");
    }
    let certified = CertifiedKey::new(vec![CertificateDer::from(public)], key);
    let mut config = rustls::ServerConfig::builder_with_provider(provider())
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .with_no_client_auth()
        .with_cert_resolver(Arc::new(AlwaysResolvesServerRawPublicKeys::new(Arc::new(
            certified,
        ))));
    config.send_tls13_tickets = 0;
    Ok(Arc::new(config))
}

/// The controller, once it has sent `PublicKey { kx_version: 2 }`. The host answers with the same choice before TLS starts, so
/// neither side has a byte of the old exchange left in flight when the handshake begins (the stream refuses to start otherwise).
pub async fn start_client(conn: &mut Stream, host_pk: &[u8]) -> ResultType<()> {
    let ack = match timeout(CONNECT_TIMEOUT, conn.next()).await? {
        Some(Ok(bytes)) => bytes,
        _ => bail!("the peer did not answer the TLS choice"),
    };
    match Message::parse_from_bytes(&ack).ok().and_then(|m| m.union) {
        Some(message::Union::PublicKey(pk)) if pk.kx_version == KX_VERSION_TLS => {}
        _ => bail!("the peer did not agree to TLS"),
    }
    let name = ServerName::try_from("systemdesk.net").map_err(|err| anyhow!("{err}"))?;
    conn.upgrade_tls_client(client_config(host_pk)?, name, CONNECT_TIMEOUT)
        .await
}

/// The host, after the controller chose version 2.
pub async fn start_server(stream: &mut Stream, sk: &[u8], pk: &[u8]) -> ResultType<()> {
    let config = server_config(sk, pk)?;
    let mut ack = Message::new();
    ack.set_public_key(PublicKey {
        kx_version: KX_VERSION_TLS,
        ..Default::default()
    });
    timeout(CONNECT_TIMEOUT, stream.send(&ack)).await??;
    stream.upgrade_tls_server(config, CONNECT_TIMEOUT).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use hbb_common::{
        sodiumoxide::crypto::sign,
        tcp::FramedStream,
        tokio::{self, io::duplex},
    };

    fn pair() -> (Stream, Stream) {
        let (a, b) = duplex(64 * 1024);
        let addr = "127.0.0.1:1".parse().unwrap();
        (
            Stream::Tcp(FramedStream::from(a, addr)),
            Stream::Tcp(FramedStream::from(b, addr)),
        )
    }

    #[tokio::test]
    async fn the_host_with_the_pinned_key_gets_a_tls_13_session() {
        let (pk, sk) = sign::gen_keypair();
        let (mut controller, mut host) = pair();
        let (c, h) = tokio::join!(
            start_client(&mut controller, &pk.0),
            start_server(&mut host, &sk.0, &pk.0)
        );
        c.unwrap();
        h.unwrap();
        assert!(controller.is_secured() && host.is_secured());
        let info = controller.encryption_info().unwrap();
        assert!(
            info.starts_with("TLS_AES_256_GCM_SHA384 TLSv1.3 Kx="),
            "{info}"
        );
        assert!(info.contains("Au=Ed25519"), "{info}");
        assert_eq!(controller.encryption_info(), host.encryption_info());

        controller.send_raw(b"from the controller".to_vec()).await.unwrap();
        host.send_raw(b"from the host".to_vec()).await.unwrap();
        assert_eq!(&host.next().await.unwrap().unwrap()[..], b"from the controller");
        assert_eq!(&controller.next().await.unwrap().unwrap()[..], b"from the host");
    }

    #[tokio::test]
    async fn a_host_with_another_key_is_refused() {
        let (pinned, _) = sign::gen_keypair();
        let (pk, sk) = sign::gen_keypair();
        let (mut controller, mut host) = pair();
        let (c, _h) = tokio::join!(
            start_client(&mut controller, &pinned.0),
            start_server(&mut host, &sk.0, &pk.0)
        );
        assert!(c.is_err());
        assert!(!controller.is_secured());
    }

    #[tokio::test]
    async fn a_peer_that_does_not_speak_tls_is_refused() {
        let (pk, _) = sign::gen_keypair();
        let (mut controller, mut other) = pair();
        let mut answer = Message::new();
        answer.set_public_key(PublicKey::new());
        other.send(&answer).await.unwrap();
        assert!(start_client(&mut controller, &pk.0).await.is_err());
    }

    #[test]
    fn a_key_pair_that_does_not_match_is_not_used() {
        let (_, sk) = sign::gen_keypair();
        let (other, _) = sign::gen_keypair();
        assert!(server_config(&sk.0, &other.0).is_err());
        assert!(server_config(&sk.0[..32], &other.0).is_err());
    }
}
