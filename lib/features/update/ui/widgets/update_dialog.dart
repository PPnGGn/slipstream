import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/utils/formatters.dart';

bool _updateDialogVisible = false;

Future<void> showUpdateDialog(BuildContext context) async {
  if (_updateDialogVisible) return;
  _updateDialogVisible = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _UpdateDialog(),
    );
  } finally {
    _updateDialogVisible = false;
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<UpdateServiceCubit>();

    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return BlocBuilder<UpdateServiceCubit, UpdateState>(
          bloc: cubit,
          builder: (context, state) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: .circular(AppDims.radiusCard),
              ),
              title: Text(_title(state)),
              content: SingleChildScrollView(
                child: _Body(
                  colors: colors,
                  textTheme: textTheme,
                  state: state,
                ),
              ),
              actions: _actions(context, cubit, state),
            );
          },
        );
      },
    );
  }

  String _title(UpdateState state) {
    return state.maybeWhen(
      error: (_) => 'Update failed',
      signatureConflict: (_, _) => 'Reinstall required',
      orElse: () => 'Update ready',
    );
  }

  List<Widget> _actions(
    BuildContext context,
    UpdateServiceCubit cubit,
    UpdateState state,
  ) {
    return state.when(
      idle: () => [_closeButton(context, cubit)],
      checking: () => [_closeButton(context, cubit)],
      upToDate: () => [_closeButton(context, cubit)],
      signatureConflict: (_, _) => [_closeButton(context, cubit)],
      downloading: (_, _) => [
        TextButton(
          onPressed: cubit.cancelDownload,
          child: const Text('Cancel'),
        ),
      ],
      readyToInstall: (_, _) => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            await cubit.install();
            if (!context.mounted) return;
            final stayOpen = cubit.state.maybeWhen(
              error: (_) => true,
              signatureConflict: (_, _) => true,
              orElse: () => false,
            );
            if (!stayOpen) Navigator.of(context).pop();
          },
          child: const Text('Install'),
        ),
      ],
      error: (_) => [_closeButton(context, cubit)],
    );
  }

  Widget _closeButton(BuildContext context, UpdateServiceCubit cubit) {
    return TextButton(
      onPressed: () {
        cubit.dismiss();
        Navigator.of(context).pop();
      },
      child: const Text('Close'),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.colors,
    required this.textTheme,
    required this.state,
  });

  final AppColors colors;
  final TextTheme textTheme;
  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    return state.when(
      idle: () => const SizedBox.shrink(),
      checking: () => const Center(child: CircularProgressIndicator()),
      upToDate: () => const Text("You're up to date"),
      downloading: (release, receivedBytes) => _DownloadingBody(
        colors: colors,
        textTheme: textTheme,
        release: release,
        receivedBytes: receivedBytes,
      ),
      readyToInstall: (release, _) =>
          _ReleaseBody(textTheme: textTheme, release: release),
      signatureConflict: (release, _) => _SignatureConflictBody(
        colors: colors,
        textTheme: textTheme,
        release: release,
      ),
      error: (message) => _ErrorBox(colors: colors, message: message),
    );
  }
}

class _SignatureConflictBody extends StatefulWidget {
  const _SignatureConflictBody({
    required this.colors,
    required this.textTheme,
    required this.release,
  });

  final AppColors colors;
  final TextTheme textTheme;
  final AppRelease release;

  @override
  State<_SignatureConflictBody> createState() => _SignatureConflictBodyState();
}

class _SignatureConflictBodyState extends State<_SignatureConflictBody> {
  final _cubit = getIt<UpdateServiceCubit>();
  var _saving = false;
  var _saveTried = false;
  String? _savedTo;

  Future<void> _save() async {
    setState(() => _saving = true);
    final location = await _cubit.exportApk();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveTried = true;
      _savedTo = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.release.version;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 12,
      children: [
        Text(
          'The installed app is signed with a different key than v$version, '
          "so Android can't update it in place.",
          style: widget.textTheme.bodyMedium,
        ),
        Text(
          '1. Save the APK\n'
          '2. Uninstall Slipstream\n'
          '3. Open the saved APK to install v$version',
          style: widget.textTheme.bodySmall,
        ),
        if (_savedTo != null)
          Text(
            'Saved to $_savedTo',
            style: widget.textTheme.labelMedium?.copyWith(
              color: widget.colors.primary,
            ),
          )
        else if (_saveTried)
          Text(
            "Couldn't save the APK. Download the latest release from GitHub, "
            'then uninstall and install it manually.',
            style: widget.textTheme.labelMedium?.copyWith(
              color: widget.colors.danger,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save APK'),
            ),
            FilledButton(
              onPressed: _cubit.uninstallForReinstall,
              child: const Text('Uninstall'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReleaseBody extends StatelessWidget {
  const _ReleaseBody({required this.textTheme, required this.release});

  final TextTheme textTheme;
  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final notes = release.notes;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        Text(
          'v${release.version} is ready to install.',
          style: textTheme.bodyMedium,
        ),
        Text(
          'Size: ${formatBytes(release.sizeBytes)}',
          style: textTheme.labelMedium,
        ),
        if (notes != null && notes.isNotEmpty)
          Text(notes, style: textTheme.bodySmall),
      ],
    );
  }
}

class _DownloadingBody extends StatelessWidget {
  const _DownloadingBody({
    required this.colors,
    required this.textTheme,
    required this.release,
    required this.receivedBytes,
  });

  final AppColors colors;
  final TextTheme textTheme;
  final AppRelease release;
  final int receivedBytes;

  @override
  Widget build(BuildContext context) {
    final progress = receivedBytes / release.sizeBytes;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        ClipRRect(
          borderRadius: .circular(AppDims.radiusChip),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            backgroundColor: colors.chip,
            color: colors.primary,
          ),
        ),
        Text(
          '${formatBytes(receivedBytes)} of ${formatBytes(release.sizeBytes)}',
          style: textTheme.labelMedium,
          textAlign: .center,
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.colors, required this.message});

  final AppColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.13),
        borderRadius: .circular(12),
        border: .all(color: colors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.danger, fontSize: 12, height: 1.5),
      ),
    );
  }
}
