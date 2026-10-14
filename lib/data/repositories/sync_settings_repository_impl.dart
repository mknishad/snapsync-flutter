import 'package:snapsync/data/local/settings_store.dart';
import 'package:snapsync/domain/repositories/sync_settings_repository.dart';

class SyncSettingsRepositoryImpl implements SyncSettingsRepository {
  const SyncSettingsRepositoryImpl(this.store);

  final SettingsStore store;

  static const pausedKey = 'sync.paused';

  @override
  Future<bool> isPaused() async => await store.read(pausedKey) == '1';

  @override
  Future<void> setPaused({required bool paused}) {
    return store.write(pausedKey, paused ? '1' : '0');
  }
}
