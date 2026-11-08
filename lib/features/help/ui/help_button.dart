import 'package:flutter/material.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/help/ui/help_sheet.dart';
import 'package:slipstream/features/help/ui/help_topic.dart';

/// The ⓘ button in a page header. [topic] is a function, not a value: some
/// topics depend on the current platform or setting, and are built when the
/// button is tapped.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.topic});

  final HelpTopic Function() topic;

  @override
  Widget build(BuildContext context) {
    return BoxIconButton(
      iconPath: AppAssets.info,
      onTap: () => showHelpSheet(context, topic()),
    );
  }
}
