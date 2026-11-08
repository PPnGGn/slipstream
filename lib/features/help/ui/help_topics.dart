import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart' show TileHue;
import 'package:slipstream/features/help/ui/help_topic.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// The texts of the help sheets, one pure function per settings page. A page
/// passes in what differs between platforms (a flag, not `Platform`), so every
/// variant can be tested. Each item's title, icon and color repeat the page's
/// own row (the titles come from the very same translations); keep them in
/// step when a row changes.
///
/// Rules for the texts: `what` says what the setting does, `why` the
/// situation it solves (not a repeat of `what`); every claim is checked
/// against the code or docs/. The texts live in lib/l10n/*.arb (keys
/// `help…`).

/// The Russian domain zones, written in their own script on purpose; the
/// translations take them as a placeholder so that they stay free of it.
const _russianZones = '.ru / .рф';

HelpNote _reconnectNote(AppLocalizations l10n) => HelpNote(
  title: l10n.helpNoteReconnectTitle,
  body: l10n.helpNoteReconnectBody,
);

HelpNote _ownRoutingNote(AppLocalizations l10n) => HelpNote(
  title: l10n.helpNoteOwnRoutingTitle,
  body: l10n.helpNoteOwnRoutingBody,
);

HelpTopic pingHelp(AppLocalizations l10n) => HelpTopic(
  title: l10n.pingTitle,
  intro: l10n.helpPingIntro,
  items: [
    HelpItem(
      iconPath: AppAssets.bolt,
      hue: TileHue.speed,
      title: l10n.pingOnLaunchTitle,
      what: l10n.helpPingLaunchWhat,
      why: l10n.helpPingLaunchWhy,
      tip: l10n.helpPingLaunchTip,
    ),
    HelpItem(
      iconPath: AppAssets.arrowDown,
      hue: TileHue.violet,
      title: l10n.pingSortTitle,
      what: l10n.helpPingSortWhat,
      why: l10n.helpPingSortWhy,
    ),
    HelpItem(
      iconPath: AppAssets.ping,
      hue: TileHue.teal,
      title: l10n.pingDisplayTitle,
      what: l10n.helpPingDisplayWhat,
      why: l10n.helpPingDisplayWhy,
    ),
  ],
  notes: [
    HelpNote(
      title: l10n.helpPingNoteMeasuredTitle,
      body: l10n.helpPingNoteMeasuredBody,
    ),
    HelpNote(
      title: l10n.helpPingNoteColorsTitle,
      body: l10n.helpPingNoteColorsBody,
    ),
  ],
);

HelpTopic subscriptionsHelp(
  AppLocalizations l10n, {
  required bool backgroundUpdates,
}) => HelpTopic(
  title: l10n.subscriptionsTitle,
  intro: l10n.helpSubsIntro,
  items: [
    HelpItem(
      iconPath: AppAssets.refresh,
      hue: TileHue.teal,
      title: l10n.autoUpdateHeader,
      what: l10n.helpSubsAutoWhat,
      why: l10n.helpSubsAutoWhy,
      tip: l10n.helpSubsAutoTip,
    ),
  ],
  notes: [
    HelpNote(
      title: l10n.helpSubsNoteWhenTitle,
      body: backgroundUpdates
          ? l10n.helpSubsNoteWhenBackground
          : l10n.helpSubsNoteWhenForeground,
    ),
    HelpNote(
      title: l10n.helpSubsNoteBlockedTitle,
      body: l10n.helpSubsNoteBlockedBody,
    ),
    HelpNote(
      title: l10n.helpSubsNoteFailedTitle,
      body: l10n.helpSubsNoteFailedBody,
    ),
  ],
);

HelpTopic dnsHelp(AppLocalizations l10n, {required bool fakeDnsAllowed}) =>
    HelpTopic(
      title: l10n.dnsTitle,
      intro: l10n.helpDnsIntro,
      items: [
        HelpItem(
          iconPath: AppAssets.cloud,
          hue: TileHue.amber,
          title: l10n.helpDnsRemoteTitle,
          what: l10n.helpDnsRemoteWhat,
          why: l10n.helpDnsRemoteWhy,
          tip: l10n.helpDnsRemoteTip,
        ),
        HelpItem(
          iconPath: AppAssets.pin,
          hue: TileHue.blue,
          title: l10n.helpDnsDirectTitle,
          what: l10n.helpDnsDirectWhat(_russianZones),
          why: l10n.helpDnsDirectWhy,
          tip: l10n.dnsDirectHint,
        ),
        if (fakeDnsAllowed)
          HelpItem(
            iconPath: AppAssets.bolt,
            hue: TileHue.pink,
            title: 'Fake DNS',
            what: l10n.helpDnsFakeWhat,
            why: l10n.helpDnsFakeWhy,
            tip: l10n.helpDnsFakeTip,
          ),
      ],
      notes: [
        _reconnectNote(l10n),
        _ownRoutingNote(l10n),
        HelpNote(
          title: l10n.helpDnsNotePrivateTitle,
          body: l10n.helpDnsNotePrivateBody,
        ),
      ],
    );

HelpTopic routingHelp(
  AppLocalizations l10n, {
  required bool fullAdBlockAllowed,
}) => HelpTopic(
  title: l10n.routingTitle,
  intro: l10n.helpRoutingIntro,
  items: [
    HelpItem(
      iconPath: AppAssets.pin,
      hue: TileHue.blue,
      title: l10n.ruBypassTitle,
      what: l10n.helpRoutingRuWhat(_russianZones),
      why: l10n.helpRoutingRuWhy,
    ),
    HelpItem(
      iconPath: AppAssets.block,
      hue: TileHue.red,
      title: l10n.adBlockTitle,
      what: fullAdBlockAllowed
          ? l10n.helpRoutingAdsWhatFull
          : l10n.helpRoutingAdsWhatLimited,
      why: l10n.helpRoutingAdsWhy,
      tip: fullAdBlockAllowed ? l10n.helpRoutingAdsTip : null,
    ),
    HelpItem(
      iconPath: AppAssets.home,
      hue: TileHue.teal,
      title: l10n.lanBypassTitle,
      what: l10n.helpRoutingLanWhat,
      why: l10n.helpRoutingLanWhy,
      tip: l10n.helpRoutingLanTip,
    ),
    HelpItem(
      iconPath: AppAssets.database,
      hue: TileHue.indigo,
      title: l10n.helpRoutingGeoTitle,
      what: l10n.helpRoutingGeoWhat,
      why: l10n.helpRoutingGeoWhy(_russianZones),
    ),
    HelpItem(
      iconPath: AppAssets.plus,
      hue: TileHue.slate,
      title: l10n.routingCustomRulesHeader,
      what: l10n.helpRoutingCustomWhat,
      why: l10n.helpRoutingCustomWhy,
      tip: l10n.helpRoutingCustomTip,
    ),
  ],
  notes: [
    _reconnectNote(l10n),
    HelpNote(
      title: l10n.helpNoteOwnRoutingTitle,
      body: l10n.helpRoutingNoteOwnBody,
    ),
  ],
);

HelpTopic securityHelp(AppLocalizations l10n) => HelpTopic(
  title: l10n.securityTitle,
  intro: l10n.helpSecurityIntro,
  items: [
    HelpItem(
      iconPath: AppAssets.kill,
      hue: TileHue.red,
      title: 'Kill switch',
      what: l10n.helpSecurityKillWhat,
      why: l10n.helpSecurityKillWhy,
      tip: l10n.helpSecurityKillTip,
    ),
    HelpItem(
      iconPath: AppAssets.ipv6,
      hue: TileHue.blue,
      title: 'IPv6',
      what: l10n.helpSecurityIpv6What,
      why: l10n.helpSecurityIpv6Why,
      tip: l10n.helpSecurityIpv6Tip,
    ),
  ],
  notes: [
    _reconnectNote(l10n),
    HelpNote(
      title: l10n.helpSecurityNoteKillTitle,
      body: l10n.helpSecurityNoteKillBody,
    ),
    HelpNote(
      title: l10n.helpSecurityNoteAlwaysOnTitle,
      body: l10n.helpSecurityNoteAlwaysOnBody,
    ),
  ],
);

HelpTopic splitTunnelHelp(AppLocalizations l10n) => HelpTopic(
  title: l10n.splitTitle,
  intro: l10n.helpSplitIntro,
  items: [
    HelpItem(
      iconPath: AppAssets.split,
      hue: TileHue.split,
      title: l10n.splitTitle,
      what: l10n.helpSplitMainWhat,
      why: l10n.helpSplitMainWhy,
    ),
    HelpItem(
      iconPath: AppAssets.apps,
      hue: TileHue.blue,
      title: '${l10n.splitModeProxy} / ${l10n.splitModeBypass}',
      what: l10n.helpSplitModesWhat,
      why: l10n.helpSplitModesWhy,
      tip: l10n.helpSplitModesTip,
    ),
    HelpItem(
      iconPath: AppAssets.sysApps,
      hue: TileHue.slate,
      title: l10n.splitSystemTitle,
      what: l10n.helpSplitSystemWhat,
      why: l10n.helpSplitSystemWhy,
    ),
  ],
  notes: [
    _reconnectNote(l10n),
    HelpNote(title: l10n.helpSplitNoteTitle, body: l10n.helpSplitNoteBody),
  ],
);

HelpTopic notificationsHelp(AppLocalizations l10n) => HelpTopic(
  title: l10n.notificationsTitle,
  intro: l10n.helpNotifIntro,
  items: [
    HelpItem(
      iconPath: AppAssets.kill,
      hue: TileHue.red,
      title: l10n.notifyTrafficBlockedTitle,
      what: l10n.helpNotifBlockedWhat,
      why: l10n.helpNotifBlockedWhy,
    ),
    HelpItem(
      iconPath: AppAssets.power,
      hue: TileHue.amber,
      title: l10n.notifyStartFailedTitle,
      what: l10n.helpNotifStartWhat,
      why: l10n.helpNotifStartWhy,
      tip: l10n.helpNotifStartTip,
    ),
  ],
  notes: [
    HelpNote(
      title: l10n.helpNotifNoteSystemTitle,
      body: l10n.helpNotifNoteSystemBody,
    ),
  ],
);
