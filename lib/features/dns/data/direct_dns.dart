/// The resolver for names whose traffic goes outside the tunnel (the RU bypass:
/// `.ru` and other Russian domains). It is asked directly, not through the VPN,
/// and is used only while the RU bypass is on.
enum DirectDns {
  /// Yandex DNS over HTTPS. The default: what the app has always used.
  yandex('https://77.88.8.8/dns-query'),

  /// The phone's own resolver (the network's DNS, usually the operator's).
  /// `localhost` is xray's name for "ask the operating system".
  system('localhost');

  const DirectDns(this.address);

  final String address;

  /// The option stored under [name]; [yandex] for null and unknown names.
  static DirectDns fromName(String? name) => DirectDns.values.firstWhere(
    (v) => v.name == name,
    orElse: () => DirectDns.yandex,
  );
}
