import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
import 'package:slipstream/features/notifications/cubit/notification_access_cubit.dart';
import 'package:slipstream/features/notifications/cubit/notifications_cubit.dart';
import 'package:slipstream/features/notifications/data/notification_prefs.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Settings → Notifications (Android): one switch per alert the VPN service
/// may show. The service decides on its own, also with the app closed; this
/// page only keeps its switches (NativePrefsRunner passes them on) and tells
/// when Android itself blocks the notifications.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  final _prefs = getIt<NotificationsCubit>();
  final _access = getIt<NotificationAccessCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _access.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The user comes back from the system settings: read the answer again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _access.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: l10n.notificationsTitle,
              actions: [HelpButton(topic: notificationsHelp)],
            ),
            Expanded(
              child: ListView(
                padding: const .fromLTRB(20, 6, 20, 28),
                children: [
                  BlocBuilder<NotificationAccessCubit, bool>(
                    bloc: _access,
                    builder: (context, allowed) => allowed
                        ? const SizedBox.shrink()
                        : _DisabledNotice(onOpenSettings: _access.openSettings),
                  ),
                  BlocBuilder<NotificationsCubit, NotificationPrefs>(
                    bloc: _prefs,
                    builder: (context, prefs) => SettingsGroup(
                      children: [
                        SettingsRow(
                          iconPath: AppAssets.kill,
                          hue: TileHue.red,
                          title: l10n.notifyTrafficBlockedTitle,
                          subtitle: l10n.notifyTrafficBlockedSubtitle,
                          switchValue: prefs.trafficBlocked,
                          onSwitch: (value) =>
                              _prefs.setTrafficBlocked(enabled: value),
                        ),
                        SettingsRow(
                          iconPath: AppAssets.power,
                          hue: TileHue.amber,
                          title: l10n.notifyStartFailedTitle,
                          subtitle: l10n.notifyStartFailedSubtitle,
                          switchValue: prefs.startFailed,
                          onSwitch: (value) =>
                              _prefs.setStartFailed(enabled: value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while Android blocks the app's notifications: the switches below
/// still work, but nothing would show.
class _DisabledNotice extends StatelessWidget {
  const _DisabledNotice({required this.onOpenSettings});

  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Container(
      margin: const .only(bottom: 14),
      padding: const .all(12),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: .circular(14),
        border: .all(color: colors.warn.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: .start,
            spacing: 10,
            children: [
              SvgPicture.asset(
                AppAssets.info,
                width: 15,
                height: 15,
                colorFilter: .mode(colors.warn, .srcIn),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.notifyDisabledTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: .w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.notifyDisabledBody,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onOpenSettings,
              child: Text(l10n.notifyOpenSettings),
            ),
          ),
        ],
      ),
    );
  }
}
