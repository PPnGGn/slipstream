/// Subtitle of the kill switch row: what it does right now.
String killSwitchSubtitle({required bool enabled}) => enabled
    ? 'Blocks traffic if the tunnel is lost'
    : 'Off · a lost tunnel just closes the VPN';

/// Subtitle of the IPv6 row: what the setting does right now.
String ipv6Subtitle({required bool enabled}) =>
    enabled ? 'IPv6 goes through the tunnel' : 'Off · apps use IPv4 only';
