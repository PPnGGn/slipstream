import 'package:slipstream/core/service/toast/toast_message.dart';

/// What a long press on a server says: it was pinned or unpinned. [serverName]
/// is the title without the flag emoji (`displayTitle`).
ToastSpec favoriteToast({required bool added, required String serverName}) =>
    ToastSpec(
      added ? 'Added to favorites' : 'Removed from favorites',
      subtitle: serverName.toUpperCase(),
      kind: added ? ToastKind.success : ToastKind.info,
    );
