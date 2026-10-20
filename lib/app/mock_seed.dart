import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/repositories/playlist_repository.dart';

/// Mock Xtream account served by `tools/mock_server` (test data only).
const kMockUsername = 'carina';
const kMockPassword = 'test123';
const kMockPlaylistName = 'Carina Demo';

/// Ensures the "Carina Demo" Xtream playlist pointing at [mockUrl] exists
/// (`--mock`, `--smoke-test`, `--capture`). [created] tells the caller to run
/// the first import.
Future<({int playlistId, bool created})> ensureMockPlaylist(
  ProviderContainer container,
  String mockUrl,
) async {
  final repo = container.read(playlistRepositoryProvider);
  final server = mockUrl.endsWith('/')
      ? mockUrl.substring(0, mockUrl.length - 1)
      : mockUrl;
  final existing = (await repo.getAll()).firstWhereOrNull(
    (p) =>
        p.type == PlaylistType.xtream &&
        p.server == server &&
        p.username == kMockUsername,
  );
  if (existing != null) return (playlistId: existing.id, created: false);
  final id = await repo.create(
    PlaylistDraft(
      name: kMockPlaylistName,
      type: PlaylistType.xtream,
      server: server,
      username: kMockUsername,
      password: kMockPassword,
      avatarId: 'animal-fox',
    ),
  );
  return (playlistId: id, created: true);
}
