import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/db/database.dart' show PlaylistType;
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/features/playlists/data/playlists_navigation.dart';
import 'package:carina/data/import/import.dart' show ImportScope;
import 'package:carina/features/playlists/data/wizard_form.dart';

void main() {
  group('fields and step numbers', () {
    test('Xtream steps follow the numbering', () {
      final fields = wizardFields(PlaylistType.xtream);
      expect(fields, [
        WizardField.name,
        WizardField.server,
        WizardField.username,
        WizardField.password,
        WizardField.epgUrl,
        WizardField.epgShift,
        WizardField.reloadFrequency,
        WizardField.save,
      ]);
      String step(WizardField f) =>
          formatStepNumber(wizardStepNumber(PlaylistType.xtream, f));
      expect(step(WizardField.name), '03');
      expect(step(WizardField.server), '04');
      expect(step(WizardField.username), '05');
      expect(step(WizardField.password), '06');
      expect(step(WizardField.epgUrl), '07');
      expect(step(WizardField.epgShift), '08');
      expect(step(WizardField.reloadFrequency), '09');
      expect(step(WizardField.save), '10');
    });

    test('M3U URL and file forms', () {
      expect(wizardFields(PlaylistType.m3u), [
        WizardField.name,
        WizardField.playlistUrl,
        WizardField.epgUrl,
        WizardField.epgShift,
        WizardField.reloadFrequency,
        WizardField.userAgent,
        WizardField.save,
      ]);
      expect(wizardFields(PlaylistType.m3uFile), contains(WizardField.file));
      expect(
        wizardFields(PlaylistType.m3uFile),
        isNot(contains(WizardField.userAgent)),
      );
      expect(wizardStepNumber(PlaylistType.m3u, WizardField.playlistUrl), 4);
      // A field the type does not show falls back to "02".
      expect(wizardStepNumber(PlaylistType.m3u, WizardField.server), 2);
    });

    test('EPG shift labels', () {
      expect(formatEpgShift(0), '0');
      expect(formatEpgShift(3), '+3');
      expect(formatEpgShift(-12), '−12');
    });
  });

  group('server address', () {
    test('accepts scheme + host + port (and a path)', () {
      for (final ok in [
        'https://domain.com:8080',
        'http://domain.com:80',
        'http://1.2.3.4:25461',
        'http://domain.com:8080/',
        'http://domain.com:8080/panel',
        '  HTTPS://Domain.com:443  ',
        'http://[::1]:8080',
      ]) {
        expect(checkServerAddress(ok), isNull, reason: ok);
      }
    });

    test('reports the first problem', () {
      expect(checkServerAddress(''), ServerProblem.empty);
      expect(checkServerAddress('   '), ServerProblem.empty);
      expect(checkServerAddress('domain.com:8080'), ServerProblem.scheme);
      expect(checkServerAddress('ftp://domain.com:21'), ServerProblem.scheme);
      expect(checkServerAddress('http://domain.com'), ServerProblem.port);
      expect(checkServerAddress('https://domain.com/xc'), ServerProblem.port);
      expect(checkServerAddress('http://[::1]'), ServerProblem.port);
      expect(
        checkServerAddress('http://domain.com:abc'),
        ServerProblem.invalid,
      );
      expect(
        checkServerAddress('http://domain.com:70000'),
        ServerProblem.invalid,
      );
      expect(checkServerAddress('http://:8080'), ServerProblem.invalid);
      expect(
        checkServerAddress('http://user:pass@domain.com:8080'),
        ServerProblem.invalid,
      );
      expect(
        checkServerAddress('http://domain.com:8080/get.php?username=a'),
        ServerProblem.invalid,
      );
    });

    test('http URL check', () {
      expect(isHttpUrl('http://a.b/list.m3u'), isTrue);
      expect(isHttpUrl('https://a.b:8080/x?y=1'), isTrue);
      expect(isHttpUrl('a.b/list.m3u'), isFalse);
      expect(isHttpUrl('file:///tmp/list.m3u'), isFalse);
      expect(isHttpUrl('http://a b'), isFalse);
      expect(isHttpUrl(''), isFalse);
    });
  });

  group('EPG URL semantics (DECISIONS 07:15)', () {
    WizardValues xtream({String epg = '', bool disabled = false}) =>
        WizardValues(
          type: PlaylistType.xtream,
          name: 'Demo',
          server: 'http://host:8080/',
          username: ' kanal ',
          password: 'test123',
          epgText: epg,
          epgDisabled: disabled,
        );

    test('Xtream: empty = provider guide (null), off = empty string', () {
      expect(xtream().draftEpgUrl, isNull);
      expect(xtream(disabled: true).draftEpgUrl, '');
      expect(
        xtream(epg: ' http://g.example/epg.xml ').draftEpgUrl,
        'http://g.example/epg.xml',
      );
    });

    test('M3U: the header guide stays the default', () {
      final values = WizardValues(
        type: PlaylistType.m3u,
        name: 'M3U',
        playlistUrl: 'http://host/list.m3u',
        epgText: 'http://host/epg.xml.gz',
        headerEpgUrl: 'http://host/epg.xml.gz',
      );
      expect(values.draftEpgUrl, isNull);
      values.epgText = 'http://other/epg.xml';
      expect(values.draftEpgUrl, 'http://other/epg.xml');
      values.epgDisabled = true;
      expect(values.draftEpgUrl, '');
    });

    test('edit form values from a stored playlist', () {
      const draft = PlaylistDraft(
        name: 'Demo',
        type: PlaylistType.xtream,
        server: 'http://host:8080',
        username: 'kanal',
        password: 'test123',
        // draftFor fills in the default URL (with the password).
        epgUrl: 'http://host:8080/xmltv.php?username=kanal&password=test123',
        epgShiftHours: 2,
        reloadFrequencyHours: 24,
      );
      final fromDefault = WizardValues.fromDraft(draft, storedEpgUrl: null);
      expect(fromDefault.epgText, isEmpty, reason: 'never show the password');
      expect(fromDefault.epgDisabled, isFalse);
      expect(fromDefault.epgShift, 2);
      expect(fromDefault.reloadHours, 24);
      expect(fromDefault.toDraft().epgUrl, isNull);

      final off = WizardValues.fromDraft(draft, storedEpgUrl: '');
      expect(off.epgDisabled, isTrue);
      expect(off.toDraft().epgUrl, '');

      final custom = WizardValues.fromDraft(
        draft,
        storedEpgUrl: 'http://g.example/epg.xml',
      );
      expect(custom.epgText, 'http://g.example/epg.xml');

      const m3u = PlaylistDraft(
        name: 'M3U',
        type: PlaylistType.m3u,
        m3uUrl: 'http://host/list.m3u',
      );
      final header = WizardValues.fromDraft(
        m3u,
        storedEpgUrl: null,
        headerEpgUrl: 'http://host/epg.xml.gz',
      );
      expect(header.epgText, 'http://host/epg.xml.gz');
      expect(header.playlistUrl, 'http://host/list.m3u');
      expect(header.toDraft().epgUrl, isNull);
    });
  });

  group('validation and draft', () {
    test('every required field of each type', () {
      expect(WizardValues(type: PlaylistType.xtream).validate().keys, [
        WizardField.name,
        WizardField.server,
        WizardField.username,
        WizardField.password,
      ]);
      expect(
        WizardValues(
          type: PlaylistType.xtream,
          server: 'host:1',
        ).validate()[WizardField.server],
        WizardProblem.serverScheme,
      );
      expect(
        WizardValues(
          type: PlaylistType.xtream,
          server: 'http://host',
        ).validate()[WizardField.server],
        WizardProblem.serverPort,
      );
      expect(WizardValues(type: PlaylistType.m3u).validate().keys, [
        WizardField.name,
        WizardField.playlistUrl,
      ]);
      expect(
        WizardValues(
          type: PlaylistType.m3u,
          name: 'x',
          playlistUrl: 'nope',
        ).validate(),
        {WizardField.playlistUrl: WizardProblem.urlInvalid},
      );
      expect(WizardValues(type: PlaylistType.m3uFile, name: 'x').validate(), {
        WizardField.file: WizardProblem.file,
      });
      expect(
        WizardValues(
          type: PlaylistType.m3u,
          name: 'x',
          playlistUrl: 'http://h/l.m3u',
          epgText: 'not a url',
        ).validate(),
        {WizardField.epgUrl: WizardProblem.epgInvalid},
      );
      // A disabled guide ignores the leftover text.
      expect(
        WizardValues(
          type: PlaylistType.m3u,
          name: 'x',
          playlistUrl: 'http://h/l.m3u',
          epgText: 'not a url',
          epgDisabled: true,
        ).validate(),
        isEmpty,
      );
    });

    test('draft of each type', () {
      final x = WizardValues(
        type: PlaylistType.xtream,
        name: '  Home  ',
        server: ' http://host:8080// ',
        username: ' kanal ',
        password: ' p@ss ',
        userAgent: 'ignored for Xtream',
        epgShift: -3,
        reloadHours: 12,
        avatarId: 'animal-fox',
      ).toDraft();
      expect(x.name, 'Home');
      expect(x.server, 'http://host:8080');
      expect(x.username, 'kanal');
      expect(x.password, ' p@ss ', reason: 'passwords are not trimmed');
      expect(x.m3uUrl, isNull);
      expect(x.userAgent, isNull);
      expect(x.epgShiftHours, -3);
      expect(x.reloadFrequencyHours, 12);
      expect(x.avatarId, 'animal-fox');

      final m = WizardValues(
        type: PlaylistType.m3u,
        name: 'M',
        playlistUrl: ' http://h/l.m3u ',
        userAgent: ' VLC/3 ',
        server: 'leftover',
      ).toDraft();
      expect(m.m3uUrl, 'http://h/l.m3u');
      expect(m.server, isNull);
      expect(m.userAgent, 'VLC/3');

      final f = WizardValues(
        type: PlaylistType.m3uFile,
        name: 'F',
        filePath: '/tmp/list.m3u',
      ).toDraft();
      expect(f.m3uUrl, '/tmp/list.m3u');
      expect(f.reloadFrequencyHours, defaultReloadFrequencyHours);
    });
  });

  test('import locations carry the scope', () {
    expect(importLocation(4), '/playlists/4/import');
    expect(
      importLocation(4, scope: ImportScope.epg),
      '/playlists/4/import?scope=epg',
    );
    expect(importScopeFromQuery('epg'), ImportScope.epg);
    expect(importScopeFromQuery('content'), ImportScope.content);
    expect(importScopeFromQuery(null), ImportScope.all);
    expect(importScopeFromQuery('bogus'), ImportScope.all);
  });
}
