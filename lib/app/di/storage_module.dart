import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_storage/file_subscription_storage.dart';
import 'package:slipstream/features/subscriptions/data/subscription_storage/subscription_storage.dart';

@module
abstract class StorageModule {
  @preResolve
  @singleton
  Future<SubscriptionStorage> subscriptionStorage(Talker talker) async {
    final baseDir = await getApplicationSupportDirectory();
    return FileSubscriptionStorage(baseDir, talker);
  }
}
