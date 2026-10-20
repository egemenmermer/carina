import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'fixtures.dart';

void main() {
  late R1Env env;
  late PlaylistRepository repo;

  setUp(() async {
    env = await R1Env.create();
    repo = PlaylistRepository(env.db, env.secrets, env.settings);
  });
  tearDown(() => env.dispose());

  const xtream = PlaylistDraft(
    name: ' Ev ',
    type: PlaylistType.xtream,
    server: 'http://panel.example:8080/',
    username: 'kanal',
    password: 'p@ss w/rd',
    epgShiftHours: 1,
    reloadFrequencyHours: 24,
  );

  group('create', () {
    test('stores the password only in the secret store', () async {
      final id = await repo.create(
        xtream.copyWith(epgUrl: xtream.defaultEpgUrl),
      );
      final row = (await repo.get(id))!;
      expect(row.name, 'Ev');
      expect(row.server, 'http://panel.example:8080');
      expect(row.username, 'kanal');
      expect(row.epgShiftHours, 1);
      expect(row.reloadFrequencyHours, 24);
      // The auto-filled default EPG URL carries the password: not stored.
      expect(row.epgUrl, isNull);
      expect(env.secrets.values[SecretStore.playlistPassword(id)], 'p@ss w/rd');
      final dump = row.toJson().values.join('|');
      expect(dump, isNot(contains('p@ss')));
      expect(
        await repo.epgUrlFor(id),
        'http://panel.example:8080/xmltv.php?username=kanal&password=p%40ss+w%2Frd',
      );
      final creds = (await repo.xtreamCredentials(id))!;
      expect(creds.password, 'p@ss w/rd');
      expect(creds.server, 'http://panel.example:8080');
    });

    test('keeps custom and switched-off EPG URLs', () async {
      final custom = await repo.create(
        xtream.copyWith(epgUrl: 'https://epg.example/guide.xml.gz'),
      );
      expect(
        (await repo.get(custom))!.epgUrl,
        'https://epg.example/guide.xml.gz',
      );
      final off = await repo.create(xtream.copyWith(epgUrl: ''));
      expect((await repo.get(off))!.epgUrl, '');
      expect(await repo.epgUrlFor(off), isNull);
      // The pure form the importer can call with the password it holds.
      final def = await repo.create(xtream);
      expect(
        effectiveEpgUrl((await repo.get(def))!, password: 'p@ss w/rd'),
        await repo.epgUrlFor(def),
      );
      expect(effectiveEpgUrl((await repo.get(def))!), isNull);
    });

    test('M3U playlists need a URL and store no password', () async {
      final id = await repo.create(
        const PlaylistDraft(
          name: 'Liste',
          type: PlaylistType.m3u,
          m3uUrl: 'http://lists.example/tv.m3u',
          userAgent: 'MyAgent/1.0',
          password: 'ignored',
        ),
      );
      final row = (await repo.get(id))!;
      expect(row.m3uUrl, 'http://lists.example/tv.m3u');
      expect(row.userAgent, 'MyAgent/1.0');
      expect(row.server, isNull);
      expect(env.secrets.values, isEmpty);
      expect(await repo.xtreamCredentials(id), isNull);
      expect(
        () =>
            repo.create(const PlaylistDraft(name: 'X', type: PlaylistType.m3u)),
        throwsArgumentError,
      );
      expect(
        () => repo.create(
          const PlaylistDraft(
            name: 'X',
            type: PlaylistType.xtream,
            server: 'http://a',
            username: 'u',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('new playlists go last in Manager order; reorder', () async {
      final a = await repo.create(xtream.copyWith(name: 'A'));
      final b = await repo.create(xtream.copyWith(name: 'B'));
      final c = await repo.create(xtream.copyWith(name: 'C'));
      expect((await repo.getAll()).map((p) => p.id), [a, b, c]);
      await repo.reorder([c, a, b]);
      expect((await repo.getAll()).map((p) => p.id), [c, a, b]);
      final stream = repo.watchAll();
      expect((await stream.first).first.id, c);
    });
  });

  group('update', () {
    test(
      'reports source changes (server, user, password, URL, type)',
      () async {
        final id = await repo.create(xtream);
        expect(await repo.update(id, xtream.copyWith(name: 'Salon')), isFalse);
        expect((await repo.get(id))!.name, 'Salon');
        // A null password keeps the stored one.
        expect(
          await repo.update(
            id,
            const PlaylistDraft(
              name: 'Salon',
              type: PlaylistType.xtream,
              server: 'http://panel.example:8080',
              username: 'kanal',
            ),
          ),
          isFalse,
        );
        expect(
          env.secrets.values[SecretStore.playlistPassword(id)],
          'p@ss w/rd',
        );
        expect(await repo.update(id, xtream.copyWith(password: 'new')), isTrue);
        expect(env.secrets.values[SecretStore.playlistPassword(id)], 'new');
        expect((await repo.xtreamCredentials(id))!.password, 'new');
        expect(
          await repo.update(
            id,
            xtream.copyWith(password: 'new', server: 'http://other:8080'),
          ),
          isTrue,
        );
        expect(
          await repo.update(
            id,
            xtream.copyWith(
              password: 'new',
              server: 'http://other:8080',
              username: 'u2',
            ),
          ),
          isTrue,
        );
        // Switching to M3U drops the password.
        expect(
          await repo.update(
            id,
            const PlaylistDraft(
              name: 'M',
              type: PlaylistType.m3u,
              m3uUrl: 'http://lists.example/a.m3u',
            ),
          ),
          isTrue,
        );
        expect(env.secrets.values, isEmpty);
        expect(
          await repo.update(
            id,
            const PlaylistDraft(
              name: 'M',
              type: PlaylistType.m3u,
              m3uUrl: 'http://lists.example/b.m3u',
            ),
          ),
          isTrue,
        );
      },
    );

    test('EPG changes are reported separately', () async {
      final id = await repo.create(xtream);
      final shifted = await repo.updateWithChanges(
        id,
        xtream.copyWith(epgShiftHours: 3),
      );
      expect(shifted, (source: false, epg: true));
      final custom = await repo.updateWithChanges(
        id,
        xtream.copyWith(epgShiftHours: 3, epgUrl: 'http://epg.example/x.xml'),
      );
      expect(custom, (source: false, epg: true));
      final same = await repo.updateWithChanges(
        id,
        xtream.copyWith(epgShiftHours: 3, epgUrl: 'http://epg.example/x.xml'),
      );
      expect(same, (source: false, epg: false));
    });

    test('a source change clears the stored account', () async {
      final id = await env.playlist(account: xtreamAccountJson());
      expect(repo.account((await repo.get(id))!), isNotNull);
      final draft = (await repo.draftFor(id))!;
      expect(draft.password, 'test123');
      expect(draft.epgUrl, contains('xmltv.php'));
      expect(await repo.update(id, draft.copyWith(username: 'other')), isTrue);
      final row = (await repo.get(id))!;
      expect(row.accountJson, isNull);
      expect(row.epgUrl, isNull);
      // Switching to M3U with the old auto-filled URL left in the field.
      final stale = (await repo.draftFor(id))!.epgUrl;
      expect(stale, contains('password=test123'));
      await repo.update(
        id,
        PlaylistDraft(
          name: 'M',
          type: PlaylistType.m3u,
          m3uUrl: 'http://lists.example/a.m3u',
          epgUrl: stale,
        ),
      );
      expect((await repo.get(id))!.epgUrl, isNull);
    });
  });

  test('delete cascades and clears secrets and settings', () async {
    final id = await repo.create(xtream);
    final other = await repo.create(xtream.copyWith(name: 'Other'));
    await env.channel(id, '1', 'TRT 1');
    await env.programme(
      id,
      'trt1',
      DateTime.utc(2026, 10, 17, 12),
      DateTime.utc(2026, 10, 17, 13),
      'Haber',
    );
    await env.favorite(id, '1');
    await env.db.customInsert(
      'INSERT INTO search_index(normalized, title, kind, ref_id, playlist_id) '
      'VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('trt 1'),
        Variable.withString('TRT 1'),
        Variable.withString('channel'),
        Variable.withString('1'),
        Variable.withInt(id),
      ],
    );
    await repo.setAccessPin(id, '1234');
    await env.secrets.write(SecretStore.parentalPin(id), 'x');
    await env.settings.set(
      PlaylistSettings.liveLayout,
      'vertical',
      playlistId: id,
    );
    await env.settings.set(AppSettings.lastPlaylistId, id);

    await repo.delete(id);

    expect(await repo.get(id), isNull);
    expect(await env.db.select(env.db.channels).get(), isEmpty);
    expect(await env.db.select(env.db.programmes).get(), isEmpty);
    expect(await env.db.select(env.db.favorites).get(), isEmpty);
    final search = await env.db
        .customSelect('SELECT COUNT(*) AS n FROM search_index')
        .getSingle();
    expect(search.read<int>('n'), 0);
    expect(
      env.secrets.values.keys.where((k) => k.startsWith('playlist.$id.')),
      isEmpty,
    );
    expect(env.secrets.values[SecretStore.playlistPassword(other)], isNotNull);
    expect(
      env.settings.isSet(PlaylistSettings.liveLayout, playlistId: id),
      isFalse,
    );
    expect(env.settings.get(AppSettings.lastPlaylistId), isNull);
    expect(await repo.get(other), isNotNull);
  });

  group('access PIN', () {
    test('stores a salted hash and verifies it', () async {
      final id = await repo.create(xtream);
      expect(await repo.verifyAccessPin(id, '0000'), isTrue);
      await repo.setAccessPin(id, '4321');
      expect((await repo.get(id))!.hasAccessPin, isTrue);
      final stored = env.secrets.values[SecretStore.playlistAccessPin(id)]!;
      expect(stored, isNot(contains('4321')));
      expect(stored, startsWith(r'v1$'));
      expect(await repo.verifyAccessPin(id, '4321'), isTrue);
      expect(await repo.verifyAccessPin(id, '1234'), isFalse);
      await repo.setAccessPin(id, '4321');
      expect(
        env.secrets.values[SecretStore.playlistAccessPin(id)],
        isNot(stored),
        reason: 'a new salt each time',
      );
      await repo.removeAccessPin(id);
      expect((await repo.get(id))!.hasAccessPin, isFalse);
      expect(await repo.verifyAccessPin(id, '9999'), isTrue);
      expect(() => repo.setAccessPin(id, '12a4'), throwsArgumentError);
    });

    test('a lost secret does not lock the playlist forever', () async {
      final id = await repo.create(xtream);
      await repo.setAccessPin(id, '1111');
      env.secrets.values.remove(SecretStore.playlistAccessPin(id));
      expect(await repo.verifyAccessPin(id, '2222'), isTrue);
      expect((await repo.get(id))!.hasAccessPin, isFalse);
    });
  });

  test('account and header parsing', () async {
    final id = await env.playlist(
      account: xtreamAccountJson(
        offset: const Duration(hours: 3),
        formats: ['m3u8'],
      ),
    );
    final account = repo.account((await repo.get(id))!)!;
    expect(account.serverUtcOffset, const Duration(hours: 3));
    expect(account.allowedOutputFormats, ['m3u8']);
    final m3u = await env.playlist(
      type: PlaylistType.m3u,
      m3uUrl: 'http://x/a.m3u',
      m3uHeader: {
        'tvgUrls': ['http://epg/a.xml'],
        'catchup': 'shift',
      },
    );
    final row = (await repo.get(m3u))!;
    expect(repo.m3uHeader(row)!.catchup, 'shift');
    expect(await repo.epgUrlFor(m3u), 'http://epg/a.xml');
    expect(repo.account(row), isNull);
    await repo.setAvatar(m3u, 'animal-07');
    expect((await repo.get(m3u))!.avatarId, 'animal-07');
  });

  test('PinHash rejects corrupt values', () {
    final h = PinHash.hash('1234');
    expect(PinHash.verify('1234', h), isTrue);
    expect(PinHash.verify('1234', 'garbage'), isFalse);
    expect(PinHash.verify('1234', null), isFalse);
    expect(PinHash.verify('1234', r'v1$!!$00'), isFalse);
  });
}
