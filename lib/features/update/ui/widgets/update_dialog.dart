import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/update/ui/update_dialog_content.dart';
import 'package:slipstream/features/update/ui/update_toasts.dart';

bool _updateDialogVisible = false;

@visibleForTesting
void resetUpdateDialogGuardForTest() => _updateDialogVisible = false;

/// Opens the update card over the app. It closes with `true` when it did its
/// job (the system installer opened, or the update was dropped with Close);
/// any other way out (Later, a tap on the dimmed background, Back) leaves a
/// downloaded update waiting, and the user is told it will come back.
Future<void> showUpdateDialog(BuildContext context) async {
  if (_updateDialogVisible) return;
  _updateDialogVisible = true;
  final updates = getIt<UpdateServiceCubit>();
  try {
    final done = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Later',
      barrierColor: const Color.fromRGBO(14, 14, 22, 0.62),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, _, _) => const UpdateDialog(),
      transitionBuilder: (context, animation, _, child) {
        // Grows from 0.9 and overshoots a little, like the design.
        final scale = Tween<double>(
          begin: 0.9,
          end: 1,
        ).chain(CurveTween(curve: const Cubic(0.2, 0.9, 0.3, 1.15)));
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation.drive(scale), child: child),
        );
      },
    );
    final stillWaiting = updates.state.maybeWhen(
      readyToInstall: (_, _) => true,
      orElse: () => false,
    );
    if (done != true && stillWaiting) showToastSpec(updateLaterToast);
  } finally {
    _updateDialogVisible = false;
  }
}

/// The update card: what is new, then Install or the reinstall steps. What it
/// says comes from [updateDialogContent]; this class keeps the taps, the busy
/// states and the layout.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final _updates = getIt<UpdateServiceCubit>();
  String? _installedVersion;
  bool _installing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInstalledVersion();
  }

  // Without it the card just shows the new version, no "old → new".
  Future<void> _loadInstalledVersion() async {
    try {
      final app = await getIt<UpdateInstaller>().getAppVersion();
      if (!mounted) return;
      setState(() => _installedVersion = '${app.version} (${app.buildNumber})');
    } on Object {
      // Left as null on purpose.
    }
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    final attempt = await _updates.install();
    if (!mounted) return;
    setState(() => _installing = false);
    final toast = installAttemptToast(attempt);
    if (toast != null) showToastSpec(toast);
    if (attempt == InstallAttempt.launched) Navigator.of(context).pop(true);
  }

  Future<void> _saveApk() async {
    setState(() => _saving = true);
    final location = await _updates.exportApk();
    if (!mounted) return;
    setState(() => _saving = false);
    showToastSpec(saveApkToast(location));
  }

  void _later() {
    if (_installing) return;
    Navigator.of(context).pop();
  }

  void _close() {
    _updates.dismiss();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BlocBuilder<UpdateServiceCubit, UpdateState>(
      bloc: _updates,
      builder: (context, state) {
        final content = updateDialogContent(state, _installedVersion);
        if (content == null) return const SizedBox.shrink();
        final reinstall = content.kind == UpdateDialogKind.reinstall;
        final accent = reinstall ? colors.warn : colors.ok;

        return Material(
          type: .transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const .symmetric(horizontal: 22, vertical: 24),
                  child: Container(
                    clipBehavior: .antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: .circular(28),
                      border: .all(color: colors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(10, 10, 20, 0.5),
                          blurRadius: 70,
                          offset: Offset(0, 30),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 190,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.topCenter,
                                  radius: 1.1,
                                  colors: [
                                    accent.withValues(alpha: 0.24),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.72],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: .min,
                          children: [
                            _Header(
                              content: content,
                              colors: colors,
                              accent: accent,
                            ),
                            if (content.items.isNotEmpty)
                              Flexible(
                                child: Padding(
                                  padding: const .symmetric(horizontal: 18),
                                  child: _ItemsBox(
                                    content: content,
                                    colors: colors,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const .fromLTRB(22, 14, 22, 0),
                              child: Row(
                                mainAxisAlignment: .center,
                                spacing: 6,
                                children: [
                                  SvgPicture.asset(
                                    reinstall
                                        ? AppAssets.info
                                        : AppAssets.refresh,
                                    width: 12,
                                    height: 12,
                                    colorFilter: .mode(
                                      colors.textMuted,
                                      .srcIn,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      content.hint,
                                      textAlign: .center,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const .fromLTRB(18, 16, 18, 18),
                              child: Column(
                                crossAxisAlignment: .stretch,
                                spacing: 6,
                                children: reinstall
                                    ? [
                                        AccentButton(
                                          label: 'Save APK',
                                          iconPath: AppAssets.download,
                                          height: 52,
                                          radius: 16,
                                          fontSize: 15,
                                          loading: _saving,
                                          onPressed: _saveApk,
                                        ),
                                        _TextAction(
                                          label: 'Uninstall',
                                          color: colors.danger,
                                          onTap: _updates.uninstallForReinstall,
                                        ),
                                        _TextAction(
                                          label: 'Close',
                                          color: colors.textSecondary,
                                          onTap: _close,
                                        ),
                                      ]
                                    : [
                                        AccentButton(
                                          label: _installing
                                              ? 'Installing…'
                                              : 'Install',
                                          iconPath: AppAssets.download,
                                          height: 52,
                                          radius: 16,
                                          fontSize: 15,
                                          loading: _installing,
                                          onPressed: _install,
                                        ),
                                        _TextAction(
                                          label: 'Later',
                                          color: colors.textSecondary,
                                          onTap: _installing ? null : _later,
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The app icon with a round badge, the small caps line, the title and the
/// "old → new" version chips.
class _Header extends StatelessWidget {
  const _Header({
    required this.content,
    required this.colors,
    required this.accent,
  });

  final UpdateDialogContent content;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final reinstall = content.kind == UpdateDialogKind.reinstall;
    final from = content.fromVersion;

    return Padding(
      padding: const .fromLTRB(22, 28, 22, 22),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 72,
            child: Stack(
              clipBehavior: .none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: .circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(10, 10, 20, 0.35),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: .circular(20),
                    child: SvgPicture.asset(
                      AppAssets.appIcon,
                      width: 72,
                      height: 72,
                    ),
                  ),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: .circle,
                      color: accent,
                      border: .all(color: colors.surfaceRaised, width: 3),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        reinstall ? AppAssets.toastError : AppAssets.download,
                        width: 12,
                        height: 12,
                        colorFilter: .mode(colors.background, .srcIn),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            content.eyebrow,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              fontWeight: .w700,
              letterSpacing: 1.33,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content.title,
            textAlign: .center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: .w700,
              letterSpacing: -0.22,
              height: 1.15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: .center,
            spacing: 8,
            children: [
              if (from != null) ...[
                _VersionChip(
                  text: from,
                  background: colors.chip,
                  color: colors.textMuted,
                  strike: true,
                ),
                SvgPicture.asset(
                  AppAssets.arrowRight,
                  width: 14,
                  height: 10,
                  colorFilter: .mode(colors.textMuted, .srcIn),
                ),
              ],
              _VersionChip(
                text: content.toVersion,
                background: colors.primarySoft,
                color: colors.accentIcon,
                bold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({
    required this.text,
    required this.background,
    required this.color,
    this.strike = false,
    this.bold = false,
  });

  final String text;
  final Color background;
  final Color color;
  final bool strike;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: .circular(100)),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          fontWeight: bold ? .w700 : .w600,
          color: color,
          decoration: strike ? .lineThrough : null,
          decorationColor: color,
        ),
      ),
    );
  }
}

/// The boxed list under the header: release notes, or the reinstall steps.
class _ItemsBox extends StatelessWidget {
  const _ItemsBox({required this.content, required this.colors});

  final UpdateDialogContent content;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: .circular(18),
        border: .all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              content.sectionLabel,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                fontWeight: .w700,
                letterSpacing: 1.33,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            for (final (index, item) in content.items.indexed) ...[
              if (index > 0) const SizedBox(height: 9),
              Row(
                crossAxisAlignment: .start,
                spacing: 10,
                children: [
                  Padding(
                    padding: const .only(top: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: colors.accentIcon,
                      ),
                      child: const SizedBox.square(dimension: 5),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A flat 44 px button under the main one (Later, Uninstall, Close).
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: .w600,
              color: onTap == null ? color.withValues(alpha: 0.45) : color,
            ),
          ),
        ),
      ),
    );
  }
}
