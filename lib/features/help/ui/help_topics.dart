import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart' show TileHue;
import 'package:slipstream/features/help/ui/help_topic.dart';

/// The texts of the help sheets, one pure function per settings page. A page
/// passes in what differs between platforms (a flag, not `Platform`), so every
/// variant can be tested. Each item's title, icon and color repeat the page's
/// own row; keep them in step when a row changes.
///
/// Rules for the texts: English; `what` says what the setting does, `why` the
/// situation it solves (not a repeat of `what`); every claim is checked
/// against the code or docs/.

const _reconnectNote = HelpNote(
  title: 'When it applies',
  body:
      'Changes take effect on reconnect. If the VPN is on, turn it off and on again.',
);

const _ownRoutingNote = HelpNote(
  title: 'Servers with their own rules',
  body:
      'If a server\'s config comes with routing rules of its own (set by the '
      'VPN provider or your panel), they are kept as they are and this '
      'page does not change them.',
);

HelpTopic pingHelp() => const HelpTopic(
  title: 'Ping',
  intro:
      'Shows how quickly each server answers, so you can pick a fast one '
      'without trying them one by one.',
  items: [
    HelpItem(
      iconPath: AppAssets.bolt,
      hue: TileHue.speed,
      title: 'Ping on launch',
      what:
          'Measures all servers when the app starts, and again when you '
          'come back to it after 10 minutes or more. A refreshed '
          'subscription is always measured.',
      why:
          'Server quality changes during the day. Fresh numbers mean you '
          'connect to what works now, not to what worked yesterday.',
      tip:
          'Off: measure by hand with the button on a subscription, or pull '
          'down on the list.',
    ),
    HelpItem(
      iconPath: AppAssets.arrowDown,
      hue: TileHue.violet,
      title: 'Sort servers by latency',
      what:
          'Reorders each list by ping once measuring finishes. The order '
          'stays fixed while measuring, so rows do not jump under your '
          'finger.',
      why: 'The fastest servers end up at the top, one tap from connecting.',
    ),
    HelpItem(
      iconPath: AppAssets.ping,
      hue: TileHue.teal,
      title: 'Latency display',
      what:
          'Numbers show the value in milliseconds. Dots show only the '
          'color.',
      why:
          'Numbers help to compare servers; dots keep a long list calm and '
          'easy to scan.',
    ),
  ],
  notes: [
    HelpNote(
      title: 'How it is measured',
      body:
          'A TCP connection to the server (UDP/QUIC for Hysteria2), up to 3 '
          'attempts, the result is the median. It is measured directly from '
          'the device, bypassing the VPN, also while connected. It proves '
          'only that the server is reachable, not that the VPN works.',
    ),
    HelpNote(
      title: 'Colors and marks',
      body:
          'green: under 80 ms\n'
          'yellow: 80–160 ms\n'
          'red: over 160 ms\n'
          'timeout: no response\n'
          'refused: connection rejected, the port is closed\n'
          'no dns: the server address was not found\n'
          'error: network error, usually on the device side\n'
          'n/a: cannot be measured for this protocol (mKCP)',
    ),
  ],
);

HelpTopic subscriptionsHelp({required bool backgroundUpdates}) => HelpTopic(
  title: 'Subscriptions',
  intro:
      'A subscription is a link to a server list kept by your provider. '
      'Here you choose how often the app re-downloads it.',
  items: const [
    HelpItem(
      iconPath: AppAssets.refresh,
      hue: TileHue.teal,
      title: 'Auto-update',
      what:
          'Downloads the list again at the chosen interval. When the '
          'provider sends its own interval, that one is used. Off stops '
          'every automatic update.',
      why:
          'Providers move servers, rotate keys and remove dead nodes. An '
          'old list slowly stops connecting, and an update fixes it before '
          'you notice.',
      tip: 'Leave it on unless your provider asks you not to refresh often.',
    ),
  ],
  notes: [
    HelpNote(
      title: 'When it runs',
      body: backgroundUpdates
          ? 'While the app is open, and in the background about once an '
                'hour when the network is up, also with the app closed.'
          : 'While the app is open and when you come back to it.',
    ),
    const HelpNote(
      title: 'Blocked links',
      body:
          'The link is loaded directly first. If that fails and the VPN is '
          'on, it is loaded again through the tunnel.',
    ),
    const HelpNote(
      title: 'When an update fails',
      body:
          'The old servers stay and "update failed" appears next to the '
          'subscription. It is retried in 30 minutes, or as soon as the '
          'VPN connects.',
    ),
  ],
);

HelpTopic dnsHelp({required bool fakeDnsAllowed}) => HelpTopic(
  title: 'DNS',
  intro:
      'DNS turns a site name into an address. Whoever answers also learns '
      'which sites you open, so it matters who you ask.',
  items: [
    const HelpItem(
      iconPath: AppAssets.cloud,
      hue: TileHue.amber,
      title: 'Remote DNS',
      what:
          'Looks up names for traffic that goes through the VPN. '
          'Cloudflare and Google use DNS over HTTPS, which is encrypted. '
          'Xray built-in is plain DNS to 1.1.1.1 inside the tunnel.',
      why:
          'Your mobile operator does not see these lookups: they travel '
          'inside the tunnel, and only the VPN server (or the DoH provider) '
          'sees them.',
      tip: 'Cloudflare DoH is a good default.',
    ),
    const HelpItem(
      iconPath: AppAssets.pin,
      hue: TileHue.blue,
      title: 'Direct DNS',
      what:
          'Looks up Russian names (.ru, .рф, Russian services) for traffic '
          'that bypasses the VPN. Yandex DNS is encrypted. The system '
          'resolver is the phone\'s own DNS, usually your operator\'s.',
      why:
          'Russian sites often answer differently, or not at all, to a '
          'resolver abroad. Asking a local one keeps them working. The '
          'system resolver is the simplest, but the operator sees those '
          'names.',
      tip: 'Used only while RU bypass is on (Routing).',
    ),
    if (fakeDnsAllowed)
      const HelpItem(
        iconPath: AppAssets.bolt,
        hue: TileHue.pink,
        title: 'Fake DNS',
        what:
            'Apps get a made-up address at once, and the VPN finds the '
            'real one later.',
        why:
            'The first connection to a site is faster, because the app does '
            'not wait for a real answer.',
        tip: 'If an app stops opening, turn it off.',
      ),
  ],
  notes: const [
    _reconnectNote,
    _ownRoutingNote,
    HelpNote(
      title: 'Private DNS in Android',
      body:
          'With strict Private DNS in Android settings, apps look names up '
          'through it and not through these resolvers.',
    ),
  ],
);

HelpTopic routingHelp({required bool fullAdBlockAllowed}) => HelpTopic(
  title: 'Routing',
  intro:
      'Decides which traffic goes through the VPN, which goes directly and '
      'which is dropped. By default everything goes through the VPN.',
  items: [
    const HelpItem(
      iconPath: AppAssets.pin,
      hue: TileHue.blue,
      title: 'RU bypass',
      what:
          'Sends .ru and .рф domains, Russian services, Russian IP '
          'addresses and torrents directly, bypassing the VPN.',
      why:
          'Banks, government sites and streaming services in Russia often '
          'refuse foreign addresses. Going direct keeps them working and '
          'saves VPN traffic and speed.',
    ),
    HelpItem(
      iconPath: AppAssets.block,
      hue: TileHue.red,
      title: 'Ad & tracker blocking',
      what: fullAdBlockAllowed
          ? 'Basic drops major ad and tracking networks (about 830 '
                'domains). Full uses an extended list (about 150,000 '
                'domains) with higher memory use and a chance of false '
                'positives.'
          : 'Drops major ad and tracking networks (about 830 domains). The '
                'extended list does not fit the memory limit of the iOS VPN '
                'extension.',
      why:
          'Fewer ads, less tracking, less traffic and a faster page load, '
          'in every app, not only in the browser.',
      tip: fullAdBlockAllowed
          ? 'Start with Basic. Switch to Full only if you still see ads.'
          : null,
    ),
    const HelpItem(
      iconPath: AppAssets.home,
      hue: TileHue.teal,
      title: 'LAN bypass',
      what:
          'Traffic to your local network (router, printer, NAS, Chromecast, '
          'localhost) is sent directly.',
      why:
          'Through a server abroad your own devices cannot be reached, '
          'because the server has no access to your home network. With the '
          'switch off they usually stop being found.',
      tip: 'Keep it on.',
    ),
    const HelpItem(
      iconPath: AppAssets.database,
      hue: TileHue.indigo,
      title: 'Geo databases',
      what:
          'Domain and IP lists that the rules above rely on. They are '
          'downloaded separately from the app and updated by hand.',
      why:
          'Without them ads are not blocked, and RU bypass covers only .ru '
          'and .рф. Refresh them from time to time: services change '
          'addresses.',
    ),
    const HelpItem(
      iconPath: AppAssets.plus,
      hue: TileHue.slate,
      title: 'Custom rules',
      what:
          'Your own rule for a domain (with its subdomains), an IP address '
          'or a range. Proxy sends it through the VPN, Direct sends it '
          'bypassing the VPN, Block drops it.',
      why:
          'For the exceptions the lists do not know: one site that only '
          'works from a foreign address, or a service you want to cut off.',
      tip:
          'The most specific rule wins: mail.google.com beats google.com. '
          'Your rules come before RU bypass, ad blocking and LAN bypass.',
    ),
  ],
  notes: const [
    _reconnectNote,
    HelpNote(
      title: 'Servers with their own rules',
      body:
          'If a server\'s config comes with routing rules of its own (set by '
          'the VPN provider or your panel), they are kept: RU bypass, ad '
          'blocking and LAN bypass do not apply to it. Custom rules do, and '
          'stand ahead of the server\'s own.',
    ),
  ],
);

HelpTopic securityHelp() => const HelpTopic(
  title: 'Security & tunnel',
  intro:
      'Protects you when the VPN breaks, and sets how the tunnel carries '
      'your traffic.',
  items: [
    HelpItem(
      iconPath: AppAssets.kill,
      hue: TileHue.red,
      title: 'Kill switch',
      what:
          'If the tunnel is lost and cannot come back (Android stopped the '
          'app, or the system restarted the VPN), traffic stays blocked '
          'until you reconnect or turn the VPN off.',
      why:
          'Without it apps quietly switch to your normal connection, and '
          'sites see your real address. With it you notice the break '
          'instead of leaking.',
      tip:
          'Turn it on if showing your real address would be a problem. A '
          'server that fails on the first connect only shows an error.',
    ),
    HelpItem(
      iconPath: AppAssets.ipv6,
      hue: TileHue.blue,
      title: 'IPv6',
      what:
          'On: IPv6 traffic goes through the tunnel as well. Off: the '
          'tunnel carries IPv4 only, and apps and sites that need IPv6 fall '
          'back to IPv4 on their own.',
      why:
          'If the server has no IPv6 exit, apps try IPv6, wait and only '
          'then fall back, so sites open slower.',
      tip: 'Leave it off unless you know your server supports IPv6.',
    ),
  ],
  notes: [
    _reconnectNote,
    HelpNote(
      title: 'What the kill switch does not cover',
      body:
          'When Android stops the app, traffic can leave the VPN for a few '
          'seconds while the tunnel comes back. If the app itself crashes, '
          'the VPN is simply gone.',
    ),
    HelpNote(
      title: 'Always-on VPN',
      body:
          'With Android\'s own Always-on VPN turned on, the system brings '
          'the VPN back even when you turn it off from the app.',
    ),
  ],
);

HelpTopic splitTunnelHelp() => const HelpTopic(
  title: 'Split tunneling',
  intro:
      'Chooses which apps use the VPN and which connect on their own, '
      'app by app.',
  items: [
    HelpItem(
      iconPath: AppAssets.split,
      hue: TileHue.split,
      title: 'Split tunneling',
      what:
          'The main switch. Your choice of mode and apps is kept when you '
          'turn it off. With no apps selected it does nothing.',
      why:
          'One VPN for the whole phone is not always right: some apps need '
          'it, others work better without it.',
    ),
    HelpItem(
      iconPath: AppAssets.apps,
      hue: TileHue.blue,
      title: 'Proxy selected / Bypass selected',
      what:
          'Proxy selected: only the apps you tick go through the tunnel, '
          'everything else connects directly. Bypass selected: the ticked '
          'apps connect directly, everything else goes through the tunnel.',
      why:
          'Bypass suits banks, government apps and games that reject a '
          'foreign address or lag through a server. Proxy suits the '
          'opposite: use the VPN for one messenger or browser only.',
      tip: 'Bypass selected is the usual choice.',
    ),
    HelpItem(
      iconPath: AppAssets.sysApps,
      hue: TileHue.slate,
      title: 'Include system apps',
      what:
          'Only changes the list: it also shows pre-installed apps that '
          'have no icon in the launcher, such as WebView and Play '
          'Services.',
      why:
          'Sometimes a background service, not the app you see, is what '
          'needs to go around the VPN.',
    ),
  ],
  notes: [
    _reconnectNote,
    HelpNote(
      title: 'Apps, not sites',
      body:
          'This works per app. To send a particular site or address '
          'around the VPN, use a custom rule in Routing.',
    ),
  ],
);
