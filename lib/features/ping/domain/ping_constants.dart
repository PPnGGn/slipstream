/// Max attempts in one measurement round. Kept low on purpose: this is
/// a liveness probe, not a load test — flooding a server with dozens
/// of connections per round can trip its own rate limiting (fail2ban,
/// `ufw limit`) and make a perfectly working server look dead on the
/// next run.
const int maxAttempts = 3;

/// Stop the round early after this many consecutive failures — no
/// point spending the remaining attempts on a server that already
/// failed twice in a row.
const int maxConsecutiveFailures = 2;

/// Per-attempt timeout: how long one probe (TCP handshake or QUIC
/// datagram round-trip) may take.
const int attemptTimeoutMs = 2000;

/// Timeout for resolving the target host before any attempt starts.
/// Kept separate from attemptTimeoutMs so a slow DNS server doesn't
/// eat into the probe budget.
const int dnsTimeoutMs = 3000;

/// Size of the outgoing QUIC probe datagram, in bytes. QUIC servers
/// (quic-go, used by hysteria2/sing-box/xray) require at least 1200
/// bytes on an unknown-version long-header packet before they'll
/// reply with Version Negotiation — smaller packets are silently
/// dropped as a spam/amplification guard.
const int quicProbeSize = 1200;

/// OS-level "connection timed out" codes for the platforms we ship to
/// (Windows WSAETIMEDOUT, Linux/macOS ETIMEDOUT). Dart surfaces our
/// own connect timeout as a SocketException carrying one of these.
const Set<int> osTimeoutErrorCodes = {10060, 110, 60};

/// OS-level "connection refused" codes (Windows WSAECONNREFUSED,
/// Linux ECONNREFUSED, macOS ECONNREFUSED). A closed port answers
/// immediately with RST — this is a live host actively saying "no",
/// worth telling apart from a silent timeout.
const Set<int> osConnectionRefusedErrorCodes = {10061, 111, 61};
