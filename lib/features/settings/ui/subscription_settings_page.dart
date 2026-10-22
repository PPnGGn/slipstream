import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/radio_dot.dart';
import 'package:slipstream/features/settings/ui/widgets/help_sheet.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_update_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/ui/auto_update_labels.dart';

/// Settings → Subscriptions: how often URL subscriptions refresh.
class SubscriptionSettingsPage extends StatelessWidget {
  const SubscriptionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<SubscriptionAutoUpdateCubit>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Subscriptions',
              actions: [
                BoxIconButton(
                  iconPath: AppAssets.info,
                  onTap: () => _showHelp(context),
                ),
              ],
            ),
            Expanded(
              child:
                  BlocBuilder<SubscriptionAutoUpdateCubit, AutoUpdateInterval>(
                    bloc: cubit,
                    builder: (context, selected) => ListView(
                      padding: const .fromLTRB(20, 0, 20, 28),
                      children: [
                        const SectionHeader('Auto-update', top: 14),
                        SettingsGroup(
                          children: [
                            for (final interval in AutoUpdateInterval.values)
                              SettingsRow(
                                title: interval.label,
                                subtitle: interval == AutoUpdateInterval.off
                                    ? 'Only from the ⋯ menu of a subscription'
                                    : null,
                                trailing: RadioDot(
                                  selected: interval == selected,
                                ),
                                onTap: () => cubit.select(interval),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showHelp(BuildContext context) {
    showHelpSheet(
      context,
      title: 'Subscriptions',
      entries: [
        const HelpEntry(
          title: 'Interval',
          body:
              'When the provider sends its own update interval, that one '
              'is used; otherwise the one chosen here. Off stops every '
              'automatic update.',
        ),
        HelpEntry(
          title: 'When it runs',
          body: Platform.isAndroid
              ? 'While the app is open, and in the background about once '
                    'an hour when the network is up — also with the app '
                    'closed.'
              : 'While the app is open and when you come back to it.',
        ),
        const HelpEntry(
          title: 'Blocked links',
          body:
              'The link is loaded directly first. If that fails and the '
              'VPN is on, it is loaded again through the tunnel.',
        ),
        const HelpEntry(
          title: 'Failures',
          body:
              'A failed update keeps the old servers and shows "update '
              'failed" next to the subscription. It is retried in 30 '
              'minutes, or as soon as the VPN connects.',
        ),
      ],
    );
  }
}
