import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('returns defaults, persists values and reloads them', () async {
    final store = SettingsStore(db);
    await store.load();
    expect(store.get(PlaylistSettings.liveLayout, playlistId: 1), 'horizontal');
    expect(store.get(AppSettings.autoOpenLastPlaylist), isFalse);

    await store.set(PlaylistSettings.liveLayout, 'vertical', playlistId: 1);
    await store.set(AppSettings.autoOpenLastPlaylist, true);
    await store.set(AppSettings.lastPlaylistId, 7);

    final reloaded = SettingsStore(db);
    await reloaded.load();
    expect(
      reloaded.get(PlaylistSettings.liveLayout, playlistId: 1),
      'vertical',
    );
    expect(
      reloaded.get(PlaylistSettings.liveLayout, playlistId: 2),
      'horizontal',
    );
    expect(reloaded.get(AppSettings.autoOpenLastPlaylist), isTrue);
    expect(reloaded.get(AppSettings.lastPlaylistId), 7);
  });

  test('reset and clearPlaylist remove values', () async {
    final store = SettingsStore(db);
    await store.load();
    await store.set(PlaylistSettings.guideZoomMinutes, 60, playlistId: 3);
    await store.set(PlaylistSettings.previewAudio, true, playlistId: 3);
    await store.reset(PlaylistSettings.guideZoomMinutes, playlistId: 3);
    expect(store.get(PlaylistSettings.guideZoomMinutes, playlistId: 3), 120);
    await store.clearPlaylist(3);
    final reloaded = SettingsStore(db);
    await reloaded.load();
    expect(reloaded.get(PlaylistSettings.previewAudio, playlistId: 3), isFalse);
  });

  test('playlist settings require a playlist id', () {
    final store = SettingsStore(db);
    expect(() => store.get(PlaylistSettings.liveLayout), throwsArgumentError);
  });

  test('memory secret store', () async {
    final s = MemorySecretStore();
    await s.write(SecretStore.playlistPassword(1), 'pw');
    await s.write(SecretStore.parentalPin(1), '1234');
    expect(await s.read(SecretStore.playlistPassword(1)), 'pw');
    await s.deleteWhere((k) => k.startsWith('playlist.1.'));
    expect(s.values, isEmpty);
  });
}
