import 'package:flutter/material.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/help/ui/help_sheet.dart';
import 'package:slipstream/features/help/ui/help_topic.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// The ⓘ button in a page header. [topic] is a function, not a value: some
/// topics depend on the current platform, setting or language, and are built
/// when the button is tapped, in the language of that moment.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.topic});

  final HelpTopic Function(AppLocalizations l10n) topic;

  @override
  Widget build(BuildContext context) {
    return BoxIconButton(
      iconPath: AppAssets.info,
      onTap: () => showHelpSheet(context, topic(context.l10n)),
    );
  }
}
