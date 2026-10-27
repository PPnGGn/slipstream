import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/clipboard.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/core/ui/widgets/sheet_parts.dart';
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
      showToast(
        "Couldn't share QR code",
        subtitle: 'TRY AGAIN OR COPY THE LINK',
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = AppColors.of(context);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const .fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                const SheetGrabber(),
                SheetTitleRow(
                  iconPath: AppAssets.share,
                  title: 'Share subscription',
                  subtitle: title,
                ),
                const SizedBox(height: 18),
                Center(child: _QrCard(data: data)),
                const SizedBox(height: 16),
                Container(
                  padding: const .symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.inputFill,
                    borderRadius: .circular(12),
                    border: .all(color: colors.border),
                  ),
                  child: Text(
                    data,
                    textAlign: .center,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: .w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anyone who scans this code can use your subscription.',
                  textAlign: .center,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
                const SizedBox(height: 18),
                AccentButton(
                  label: 'Share',
                  iconPath: AppAssets.share,
                  loading: _sharing,
                  onPressed: _share,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    copyToClipboard(
                      data,
                      title: 'Link copied',
                      subtitle: 'SUBSCRIPTION URL · READY TO PASTE',
                    );
                    Navigator.of(context).pop();
                  },
                  behavior: .opaque,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: colors.chip,
                      borderRadius: .circular(15),
                      border: .all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: .center,
                      spacing: 8,
                      children: [
                        SvgPicture.asset(
                          AppAssets.copy,
                          width: 14,
                          height: 14,
                          colorFilter: .mode(colors.textPrimary, .srcIn),
                        ),
                        Text(
                          'Copy URL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: .w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Dark on white in every theme, the dark theme included: many scanners
// cannot read an inverted code. The padding is the quiet zone the scanner
// needs.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2E2F45);
    return Container(
      padding: const .all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: .circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x380F0F1A),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        size: 200,
        padding: .zero,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(eyeShape: .square, color: ink),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: .square,
          color: ink,
        ),
      ),
    );
  }
}
