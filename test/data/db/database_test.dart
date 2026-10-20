import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('creates schema and inserts a playlist', () async {
    final id = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Test',
            type: PlaylistType.xtream,
            createdAt: DateTime(2026),
          ),
        );
    final row = await (db.select(
      db.playlists,
    )..where((p) => p.id.equals(id))).getSingle();
    expect(row.name, 'Test');
    expect(row.reloadFrequencyHours, 72);
  });

  test('FTS5 search index supports prefix queries', () async {
    await db.customInsert(
      'INSERT INTO search_index(normalized, title, kind, ref_id, playlist_id) '
      'VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('sicak kafa'),
        Variable.withString('Sıcak Kafa'),
        Variable.withString('series'),
        Variable.withString('42'),
        Variable.withInt(1),
      ],
    );
    final rows = await db
        .customSelect(
          'SELECT title FROM search_index WHERE search_index MATCH ?',
          variables: [Variable.withString('sic* kaf*')],
        )
        .get();
    expect(rows.single.read<String>('title'), 'Sıcak Kafa');
  });

  test('deleting a playlist cascades to its channels', () async {
    final id = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'P',
            type: PlaylistType.m3u,
            createdAt: DateTime(2026),
          ),
        );
    await db
        .into(db.channels)
        .insert(
          ChannelsCompanion.insert(
            playlistId: id,
            providerId: '1',
            name: 'TRT 1 HD',
            displayName: 'TRT 1',
          ),
        );
    await (db.delete(db.playlists)..where((p) => p.id.equals(id))).go();
    expect(await db.select(db.channels).get(), isEmpty);
  });
}
