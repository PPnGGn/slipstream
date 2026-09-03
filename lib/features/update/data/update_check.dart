import 'package:slipstream/core/models/app_release/app_release.dart';

sealed class UpdateCheck {
  const UpdateCheck();
}

final class UpdateCheckUpToDate extends UpdateCheck {
  const UpdateCheckUpToDate();
}

final class UpdateCheckReady extends UpdateCheck {
  const UpdateCheckReady({required this.release, required this.filePath});

  final AppRelease release;
  final String filePath;
}

final class UpdateCheckNeedsDownload extends UpdateCheck {
  const UpdateCheckNeedsDownload({
    required this.release,
    required this.filePath,
    required this.existingBytes,
  });

  final AppRelease release;
  final String filePath;
  final int existingBytes;
}
