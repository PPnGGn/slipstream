import 'dart:ui';

/// Icon-tile colors in Settings: one per settings row (design `HUES`), plus
/// plain color names for the rows inside sub-pages (design `SUBMAP`).
enum TileHue {
  appearance,
  auto,
  routing,
  split,
  security,
  speed,
  dns,
  backup,
  notif,
  assistant,
  logs,
  version,
  red,
  amber,
  green,
  teal,
  blue,
  indigo,
  violet,
  pink,
  slate,
}

/// Every color of one theme. Values come from design v3
/// (SlipStream App v3.dc.html: `T`, `SEM`, `HUES`); the comment next to a
/// field is its CSS variable there.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.inputFill,
    required this.chip,
    required this.rowHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.accentIcon,
    required this.primarySoft,
    required this.selectedRow,
    required this.segment,
    required this.brandGradient,
    required this.ink,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.ringGradient,
    required this.auraOn,
    required this.auraOff,
    required this.glow,
    required this.connectedLine,
    required this.connectedFill,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.tileHues,
  });

  final Brightness brightness;

  final Color background; // --bg
  final Color surface; // --sur: cards
  final Color surfaceRaised; // --ras: sheets, menus
  final Color border; // --brd
  final Color inputFill; // --inp
  final Color chip; // --chip
  final Color rowHover; // --rowh: pressed row
  final Color textPrimary; // --tx1
  final Color textSecondary; // --tx2
  final Color textMuted; // --tx3
  final Color primary; // --pri: selected-row edge, ↑↓ arrows
  final Color accentIcon; // --picon: icons and check marks in the accent
  final Color primarySoft; // --psoft: soft accent backgrounds
  final Color selectedRow; // --selbg
  final Color segment; // --seg: selected segment of a segmented control
  final List<Color> brandGradient; // --acc: buttons, switches when on
  final Color ink; // --accTx: text and icons on brandGradient

  final Color ok;
  final Color warn;
  final Color danger;

  /// Connect ring when connected, sweeps ringA → ringB → ok.
  final List<Color> ringGradient;
  final Color auraOn; // glow behind the home header while connected
  final Color auraOff; // the same glow while disconnected
  final Color glow; // pulse inside the connect ring
  final Color connectedLine; // compact bar border while connected
  final Color connectedFill; // compact bar switch track while connected

  final Color inverseSurface; // toast / SnackBar background
  final Color onInverseSurface;

  /// Null: every tile uses [accentIcon] (Phosphor is monochrome).
  final Map<TileHue, Color>? tileHues;

  // WaveSwitch knob: white in every theme.
  Color get switchKnob => const Color(0xFFFFFFFF);
  Color get switchKnobShadow => const Color(0x4D14141F);

  Color tileHue(TileHue hue) => tileHues?[hue] ?? accentIcon;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF22222E),
    surface: Color(0xFF2B2C3E),
    surfaceRaised: Color(0xFF333450),
    border: Color(0xFF3E3F5C),
    inputFill: Color(0xFF1D1D28),
    chip: Color(0xFF393A5A),
    rowHover: Color(0x0AE9E9E9),
    textPrimary: Color(0xFFE9E9E9),
    textSecondary: Color(0xFFADA9BA),
    textMuted: Color(0xFF706F8E),
    primary: Color(0xFFADA9BA),
    accentIcon: Color(0xFFADB5D3),
    primarySoft: Color(0x29ADB5D3),
    selectedRow: Color(0x1AADB5D3),
    segment: Color(0xFF4A4B70),
    brandGradient: [Color(0xFFADB5D3), Color(0xFFB0C3C9)],
    ink: Color(0xFF2E2F45),
    ok: Color(0xFF8CC3A8),
    warn: Color(0xFFD9B36A),
    danger: Color(0xFFD98A9C),
    ringGradient: [Color(0xFFADB5D3), Color(0xFFB0C3C9), Color(0xFF8CC3A8)],
    auraOn: Color(0x298CC3A8),
    auraOff: Color(0x26ADB5D3),
    glow: Color(0x598CC3A8),
    connectedLine: Color(0x738CC3A8),
    connectedFill: Color(0x478CC3A8),
    inverseSurface: Color(0xFFE9E9E9),
    onInverseSurface: Color(0xFF2E2F45),
    tileHues: {
      TileHue.appearance: Color(0xFF7C9CFF),
      TileHue.auto: Color(0xFF5FD08A),
      TileHue.routing: Color(0xFFB48CFF),
      TileHue.split: Color(0xFF4CC9C0),
      TileHue.security: Color(0xFF9C8CFF),
      TileHue.speed: Color(0xFFE9C25B),
      TileHue.dns: Color(0xFF5EA8FF),
      TileHue.backup: Color(0xFF6E8BFF),
      TileHue.notif: Color(0xFFF07878),
      TileHue.assistant: Color(0xFFC79BFF),
      TileHue.logs: Color(0xFF8FA3BF),
      TileHue.version: Color(0xFFB48CFF),
      TileHue.red: Color(0xFFF07878),
      TileHue.amber: Color(0xFFE9C25B),
      TileHue.green: Color(0xFF5FD08A),
      TileHue.teal: Color(0xFF4CC9C0),
      TileHue.blue: Color(0xFF5EA8FF),
      TileHue.indigo: Color(0xFF7C9CFF),
      TileHue.violet: Color(0xFFB48CFF),
      TileHue.pink: Color(0xFFF28FC6),
      TileHue.slate: Color(0xFF8FA3BF),
    },
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF9F3F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    border: Color(0xFFE1DBE5),
    inputFill: Color(0xFFF7F2F5),
    chip: Color(0xFFEFEAF0),
    rowHover: Color(0x0D393A5A),
    textPrimary: Color(0xFF2E2F45),
    textSecondary: Color(0xFF706F8E),
    textMuted: Color(0xFFADA9BA),
    primary: Color(0xFF8B93BF),
    accentIcon: Color(0xFF8B93BF),
    primarySoft: Color(0x248B93BF),
    selectedRow: Color(0x1A8B93BF),
    segment: Color(0xFFFFFFFF),
    brandGradient: [Color(0xFFADB5D3), Color(0xFFB0C3C9)],
    ink: Color(0xFF2E2F45),
    ok: Color(0xFF55917A),
    warn: Color(0xFFA97F35),
    danger: Color(0xFFB75D75),
    ringGradient: [Color(0xFFADB5D3), Color(0xFF8B93BF), Color(0xFF55917A)],
    auraOn: Color(0x2455917A),
    auraOff: Color(0x47ADB5D3),
    glow: Color(0x4055917A),
    connectedLine: Color(0x6655917A),
    connectedFill: Color(0x3855917A),
    inverseSurface: Color(0xFF2E2F45),
    onInverseSurface: Color(0xFFF9F3F5),
    tileHues: {
      TileHue.appearance: Color(0xFF4F6FD8),
      TileHue.auto: Color(0xFF2F9A5E),
      TileHue.routing: Color(0xFF8257D8),
      TileHue.split: Color(0xFF1F9990),
      TileHue.security: Color(0xFF6A58D6),
      TileHue.speed: Color(0xFFB8901F),
      TileHue.dns: Color(0xFF2F7FD8),
      TileHue.backup: Color(0xFF4462D8),
      TileHue.notif: Color(0xFFD04A4A),
      TileHue.assistant: Color(0xFF9A62E0),
      TileHue.logs: Color(0xFF5E7290),
      TileHue.version: Color(0xFF8257D8),
      TileHue.red: Color(0xFFD04A4A),
      TileHue.amber: Color(0xFFB8901F),
      TileHue.green: Color(0xFF2F9A5E),
      TileHue.teal: Color(0xFF1F9990),
      TileHue.blue: Color(0xFF2F7FD8),
      TileHue.indigo: Color(0xFF4F6FD8),
      TileHue.violet: Color(0xFF8257D8),
      TileHue.pink: Color(0xFFC9488F),
      TileHue.slate: Color(0xFF5E7290),
    },
  );

  /// True-black OLED with a terminal-green accent. The accent is solid
  /// (both gradient stops equal) and the tiles are monochrome.
  static const phosphor = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF0E0E10),
    surfaceRaised: Color(0xFF18181B),
    border: Color(0xFF232327),
    inputFill: Color(0xFF08080A),
    chip: Color(0xFF18181B),
    rowHover: Color(0x0AFFFFFF),
    textPrimary: Color(0xFFF2F2F2),
    textSecondary: Color(0xFF8E8E96),
    textMuted: Color(0xFF5E5E66),
    primary: Color(0xFF16A84A),
    accentIcon: Color(0xFF16A84A),
    primarySoft: Color(0x1F16A84A),
    selectedRow: Color(0x0F16A84A),
    segment: Color(0xFF26262B),
    brandGradient: [Color(0xFF16A84A), Color(0xFF16A84A)],
    ink: Color(0xFF03140A),
    ok: Color(0xFF16A84A),
    warn: Color(0xFFE9C25B),
    danger: Color(0xFFF07878),
    ringGradient: [Color(0xFF0B5C28), Color(0xFF16A84A), Color(0xFF16A84A)],
    auraOn: Color(0x2416A84A),
    auraOff: Color(0x0D16A84A),
    glow: Color(0x5916A84A),
    connectedLine: Color(0x7316A84A),
    connectedFill: Color(0x3D16A84A),
    inverseSurface: Color(0xFFE9E9E9),
    onInverseSurface: Color(0xFF2E2F45),
    tileHues: null,
  );
}
