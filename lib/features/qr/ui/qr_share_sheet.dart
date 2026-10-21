import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/clipboard.dart';
import 'package:slipstream/features/qr/data/qr_share_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

// Shows [data] as a QR code another phone can scan.
Future<void> showQrShareSheet(
  BuildContext context, {
  required String title,
  required String data,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QrShareSheet(title: title, data: data),
  );
}

class _QrShareSheet extends StatefulWidget {
  const _QrShareSheet({required this.title, required this.data});

  final String title;
  final String data;

  @override
  State<_QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends State<_QrShareSheet> {
  bool _sharing = false;

  String get title => widget.title;
  String get data => widget.data;

  // The sheet stays open afterwards, so the code can be shared again.
  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await getIt<QrShareService>().shareQr(data: data, name: title);
    } on Object catch (e, st) {
      getIt<Talker>().handle(e, st, 'QR: share failed');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not share the QR code')),
          );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const .fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const .only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: .circular(100),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                const SizedBox(height: 16),
                Center(child: _QrCard(data: data)),
                const SizedBox(height: 16),
                Text(
                  data,
                  textAlign: .center,
                  maxLines: 2,
                  overflow: .ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anyone who scans this code can use your subscription.',
                  textAlign: .center,
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: SvgPicture.asset(
                    AppAssets.share,
                    width: 15,
                    height: 15,
                    colorFilter: .mode(
                      Theme.of(context).colorScheme.onPrimary,
                      .srcIn,
                    ),
                  ),
                  label: const Text('Share'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    copyToClipboard(context, data, 'URL copied');
                    Navigator.of(context).pop();
                  },
                  icon: SvgPicture.asset(
                    AppAssets.copy,
                    width: 15,
                    height: 15,
                    colorFilter: .mode(colors.textPrimary, .srcIn),
                  ),
                  label: const Text('Copy URL'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Always black on white, even in the dark theme: many scanners cannot read
// an inverted code. The padding is the quiet zone the scanner needs.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: .circular(16),
      child: QrImageView(
        data: data,
        size: 260,
        padding: const .all(16),
        backgroundColor: Colors.white,
      ),
    );
  }
}
