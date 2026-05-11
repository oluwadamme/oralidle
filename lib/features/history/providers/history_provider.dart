import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analysis/data/models/session_record.dart';
import '../../../core/services/storage_service.dart';
import '../../analysis/providers/analysis_provider.dart';

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
  return HistoryNotifier(ref.watch(storageServiceProvider));
});
