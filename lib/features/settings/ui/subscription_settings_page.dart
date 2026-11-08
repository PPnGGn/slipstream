import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/radio_dot.dart';
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_update_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/ui/auto_update_labels.dart';
import 'package:slipstream/l10n/l10n_context.dart';

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
              title: context.l10n.subscriptionsTitle,
              actions: [
                HelpButton(
                  topic: (l10n) => subscriptionsHelp(
                    l10n,
                    backgroundUpdates: Platform.isAndroid,
                  ),
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
                        SectionHeader(context.l10n.autoUpdateHeader, top: 14),
                        SettingsGroup(
                          children: [
                            for (final interval in AutoUpdateInterval.values)
                              SettingsRow(
                                title: interval.label(context.l10n),
                                subtitle: interval == AutoUpdateInterval.off
                                    ? context.l10n.autoUpdateOffHint
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
}
