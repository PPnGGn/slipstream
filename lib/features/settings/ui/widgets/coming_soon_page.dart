import 'package:flutter/material.dart';
import 'package:slipstream/core/ui/widgets/coming_soon_banner.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';

/// Frame of a settings page whose feature is not built yet: the header, the
/// "Coming soon" banner and the page's (inactive) controls under it.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: title),
            Expanded(
              child: ListView(
                padding: const .fromLTRB(20, 6, 20, 28),
                children: [const ComingSoonBanner(), ...children],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
