/// The set of geo categories present in the installed .dat files, from the
/// release's `categories.json`. The connect-time gate ([GeoConfigGate]) keeps a
/// `geosite:`/`geoip:` token in a config only if it's in here — anything else
/// would make xray fail to build.
class GeoCatalog {
  const GeoCatalog({required this.site, required this.ip});

  const GeoCatalog.empty() : site = const {}, ip = const {};

  /// Lower-cased tokens, e.g. `geosite:category-ru`, `geoip:ru`.
  final Set<String> site;
  final Set<String> ip;

  bool get isEmpty => site.isEmpty && ip.isEmpty;

  /// `token` may be any case, with or without surrounding whitespace.
  bool has(String token) {
    final t = token.trim().toLowerCase();
    return site.contains(t) || ip.contains(t);
  }

  factory GeoCatalog.fromJson(Map<String, dynamic> json) {
    Set<String> lower(Object? list) => {
      for (final e in (list as List? ?? const []))
        (e as String).trim().toLowerCase(),
    };
    return GeoCatalog(site: lower(json['site']), ip: lower(json['ip']));
  }

  Map<String, dynamic> toJson() => {
    'site': site.toList()..sort(),
    'ip': ip.toList()..sort(),
  };
}
