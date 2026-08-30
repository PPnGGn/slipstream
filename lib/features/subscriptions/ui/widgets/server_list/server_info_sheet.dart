import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/clipboard.dart';
import 'package:slipstream/core/utils/formatters.dart';

Future<void> showServerInfoSheet(BuildContext context, VpnServer server) {
  final media = MediaQuery.of(context);
  final maxHeight =
      media.size.height - media.viewPadding.top - kToolbarHeight - 8;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (context) => _ServerInfoSheet(server: server),
  );
}

class _ServerInfoSheet extends StatelessWidget {
  const _ServerInfoSheet({required this.server});

  final VpnServer server;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;
        final pretty = prettyJson(server.configJson);

        return SafeArea(
          child: Padding(
            padding: const .fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisSize: .min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(server.title, style: textTheme.titleMedium),
                    ),
                    IconButton(
                      onPressed: () =>
                          copyToClipboard(context, pretty, 'Config copied'),
                      icon: SvgPicture.asset(
                        AppAssets.copy,
                        width: 18,
                        height: 18,
                        colorFilter: .mode(colors.textSecondary, .srcIn),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const .all(14),
                      decoration: BoxDecoration(
                        color: colors.inputFill,
                        borderRadius: .circular(AppDims.radiusControl),
                      ),
                      child: SelectableText(
                        pretty,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
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
