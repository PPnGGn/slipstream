import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/coming_soon_banner.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';

/// Settings → Assistant. Not built yet: the chat's empty state with its
/// suggestions and the input bar, all inactive.
class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  static const _suggestions = [
    'Why is my connection slow?',
    'VLESS REALITY or WireGuard — which to pick?',
    'How do I keep my banking app off the VPN?',
    'What does the kill switch do?',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(colors: colors),
            Expanded(
              child: ListView(
                padding: const .fromLTRB(16, 16, 16, 8),
                children: [
                  const ComingSoonBanner(),
                  const SizedBox(height: 18),
                  Center(child: _WaveTile(colors: colors, size: 56)),
                  const SizedBox(height: 14),
                  Text(
                    'How can I help?',
                    textAlign: .center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: .w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Questions about protocols, speed, routing or app '
                    'settings.',
                    textAlign: .center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SectionHeader('Try asking'),
                  Opacity(
                    opacity: 0.45,
                    child: SettingsGroup(
                      children: [
                        for (final question in _suggestions)
                          _Suggestion(colors: colors, text: question),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _InputBar(colors: colors),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        spacing: 10,
        children: [
          BoxIconButton(
            iconPath: AppAssets.arrowLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          _WaveTile(colors: colors, size: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              spacing: 1,
              children: [
                Text(
                  'Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: .w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'AI · VPN & APP HELP',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: .w600,
                    letterSpacing: 0.7,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The brand wave on an accent tile (the app's mark in the chat).
class _WaveTile extends StatelessWidget {
  const _WaveTile({required this.colors, required this.size});

  final AppColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: .center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.brandGradient),
        borderRadius: .circular(size * 0.32),
      ),
      child: SvgPicture.asset(
        AppAssets.wave,
        width: size * 0.47,
        height: size * 0.47,
        colorFilter: .mode(colors.ink, .srcIn),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.colors, required this.text});

  final AppColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 14, vertical: 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: .w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          SvgPicture.asset(
            AppAssets.arrowRight,
            width: 13,
            height: 13,
            colorFilter: .mode(colors.textMuted, .srcIn),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: .min,
        spacing: 7,
        children: [
          Opacity(
            opacity: 0.45,
            child: Container(
              padding: const .fromLTRB(14, 5, 5, 5),
              decoration: BoxDecoration(
                color: colors.inputFill,
                borderRadius: .circular(18),
                border: .all(color: colors.border, width: 1.5),
              ),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      'Ask about VPN or the app…',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: .w500,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    alignment: .center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors.brandGradient),
                      borderRadius: .circular(13),
                    ),
                    child: SvgPicture.asset(
                      AppAssets.arrowUp,
                      width: 16,
                      height: 16,
                      colorFilter: .mode(colors.ink, .srcIn),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'AI can make mistakes. Never paste private keys or UUIDs.',
            textAlign: .center,
            style: TextStyle(fontSize: 10, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
