import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/interview/data/repositories/interview_repository.dart';
import '../../features/interview/data/repositories/interview_repository_impl.dart';
import '../services/analytics/analytics_service.dart';
import '../services/analytics/event_queue.dart';
import '../services/app_prefs.dart';
import '../services/storage_scope.dart';
import '../services/storage_service.dart';
import '../services/supabase/remote_store.dart';
import '../services/supabase/supabase_bootstrap.dart';
import '../services/sync/sync_outbox.dart';
import '../services/sync/sync_service.dart';

final storageScopeProvider = Provider<StorageScope>((_) => StorageScope());

final syncOutboxProvider = Provider<SyncOutbox>((_) => SyncOutbox());

final appPrefsProvider = Provider<AppPrefs>((_) => AppPrefs());

final localDataVersionProvider = StateProvider<int>((_) => 0);

final remoteStoreProvider = Provider<RemoteStore?>((_) {
  final client = SupabaseBootstrap.client;
  return client == null ? null : SupabaseRemoteStore(client);
});

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(
    ref.watch(storageScopeProvider),
    ref.watch(syncOutboxProvider),
  ),
);

final interviewRepositoryProvider = Provider<InterviewRepository>(
  (ref) => InterviewRepositoryImpl(
    ref.watch(storageScopeProvider),
    ref.watch(syncOutboxProvider),
  ),
);

final eventQueueProvider = Provider<EventQueue>((_) => EventQueue());

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.watch(eventQueueProvider)),
);


final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return const Stream<SyncStatus>.empty();
  return sync.status;
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final remote = ref.watch(remoteStoreProvider);
  if (remote == null) return null;
  return SyncService(
    remote: remote,
    outbox: ref.watch(syncOutboxProvider),
    storage: ref.watch(storageServiceProvider),
    interviews: ref.watch(interviewRepositoryProvider),
    prefs: ref.watch(appPrefsProvider),
    scope: ref.watch(storageScopeProvider),
    events: ref.watch(eventQueueProvider),
  )..onLocalDataChanged = () =>
      ref.read(localDataVersionProvider.notifier).state++;
});
