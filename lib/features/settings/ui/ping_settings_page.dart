import 'package:flutter/material.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_settings_section.dart';
import 'package:slipstream/l10n/l10n_context.dart';

class PingSettingsPage extends StatelessWidget {
  const PingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: context.l10n.pingTitle,
              actions: [HelpButton(topic: pingHelp)],
            ),
            Expanded(
              child: ListView(
                padding: const .fromLTRB(20, 14, 20, 28),
                children: const [PingSettingsSection()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
