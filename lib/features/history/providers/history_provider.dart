import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analysis/data/models/session_record.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/storage_service.dart';

class HistoryNotifier extends StateNotifier<List<SessionRecord>> {
  HistoryNotifier(this._storage) : super([]) {
    _load();
  }

  final StorageService _storage;

  void _load() => state = _storage.getSessions();

  void refresh() => state = _storage.getSessions();

  Future<void> delete(String id) async {
    await _storage.deleteSession(id);
    state = _storage.getSessions();
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<SessionRecord>>((ref) {
      // Rebuilds the notifier — and so re-reads Hive — whenever a sync lands
      // new rows or the account scope changes.
      ref.watch(localDataVersionProvider);
      return HistoryNotifier(ref.watch(storageServiceProvider));
    });
