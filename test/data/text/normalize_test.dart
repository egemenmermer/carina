import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/text/normalize.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('normalizeForSearch – Turkish', () {
    const cases = {
      'Sıcak Kafa': 'sicak kafa',
      'İSTANBUL': 'istanbul',
      'ŞOW TV FHD': 'sow tv',
      'Çocuk Kilitli': 'cocuk kilitli',
      'ĞĞĞ ğğğ': 'ggg ggg',
      'IĞDIR': 'igdir',
      'ılık İnce ISPARTA': 'ilik ince isparta',
      'Kış Uykusu': 'kis uykusu',
      'Haber Canlı HLS': 'haber canli hls',
      'Öğretmen Ünlü': 'ogretmen unlu',
      'ŞÇĞÜÖİI şçğüöıi': 'scguoii scguoii',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(normalizeForSearch(input), expected);
      });
    });

    test('decomposed (NFD) Turkish letters fold the same way', () {
      // S + combining cedilla, I + combining dot above, g + combining breve.
      expect(
        normalizeForSearch('S\u0327ov I\u0307zmir g\u0306'),
        'sov izmir g',
      );
    });
  });

  group('normalizeForSearch – other diacritics', () {
    const cases = {
      'Pokémon': 'pokemon',
      'Crème Brûlée': 'creme brulee',
      'São Paulo': 'sao paulo',
      'Ñandú': 'nandu',
      'ÀÁÂÃÄÅ àáâãäå': 'aaaaaa aaaaaa',
      'ÈÉÊË ÌÍÎÏ ÒÓÔÕÖØ ÙÚÛÜ Ýý ÿ': 'eeee iiii oooooo uuuu yy y',
      'Straße': 'strasse',
      'Ærø': 'aero',
      'Œuvre œil': 'oeuvre oeil',
      'Łódź': 'lodz',
      'Đorđe': 'dorde',
      'Știri Țară': 'stiri tara',
      'Azərbaycan': 'azerbaycan',
      'Ελλάδα': 'ελλαδα',
      'Ёлка': 'елка',
      'Россия 24': 'россия 24',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(normalizeForSearch(input), expected);
      });
    });

    test('fullwidth, mathematical and digit forms fold to ASCII', () {
      expect(normalizeForSearch('ＴＲＴ １'), 'trt 1');
      expect(normalizeForSearch('𝐓𝐑𝐓 𝟏'), 'trt 1');
      expect(normalizeForSearch('قناة ٣'), 'قناة 3');
    });
  });

  group('normalizeForSearch – quality tokens', () {
    const cases = {
      'Show TV HD': 'show tv',
      'TRT 1 FHD': 'trt 1',
      'UHD Test 4K': 'test',
      'Movie H.265': 'movie',
      'Movie H 265 hevc x265 HDR HDR10': 'movie',
      'Kanal 50FPS': 'kanal',
      'Kanal 50 fps': 'kanal',
      'Show Full HD': 'show',
      'Ultra HD Kanal': 'kanal',
      'TV8 1080p': 'tv8',
      'TV8 720p50': 'tv8',
      'Sky 8K SD': 'sky',
      'TRT ʜᴅ': 'trt',
      'TRT ᴴᴰ': 'trt',
      'beIN Sports 1 HD+': 'bein sports 1',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(normalizeForSearch(input), expected);
      });
    });

    test('words that only contain a token stay', () {
      expect(normalizeForSearch('HDTV'), 'hdtv');
      expect(normalizeForSearch('Hdfilm SHD 4Kids'), 'hdfilm shd 4kids');
      expect(normalizeForSearch('Full Moon'), 'full moon');
      expect(normalizeForSearch('H 264'), 'h 264');
      expect(normalizeForSearch('Kanal 50'), 'kanal 50');
    });
  });

  group('normalizeForSearch – punctuation', () {
    const cases = {
      "Grey's Anatomy": 'greys anatomy',
      'Türkiye’nin Gururu': 'turkiyenin gururu',
      'S.W.A.T.': 'swat',
      'U.S. Open': 'us open',
      'E.T. the Extra-Terrestrial': 'et the extra terrestrial',
      'Dr.House': 'dr house',
      'Spider-Man: No Way Home': 'spider man no way home',
      '  many    spaces\tand\nlines  ': 'many spaces and lines',
      '🔥 Hot 🔥': 'hot',
      '🇹🇷 Ulusal': 'ulusal',
      '[TR] | Haber ★ Kanalı': 'tr haber kanali',
      'a_b/c\\d': 'a b c d',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(normalizeForSearch(input), expected);
      });
    });

    test('blank and punctuation-only input give an empty string', () {
      expect(normalizeForSearch(''), '');
      expect(normalizeForSearch('   '), '');
      expect(normalizeForSearch('!!! --- ***'), '');
      expect(normalizeForSearch('HD'), '');
    });

    test('is idempotent', () {
      const inputs = [
        'Sıcak Kafa',
        'ŞOW TV FHD',
        "Grey's Anatomy",
        'S.W.A.T.',
        'Россия 24',
        'Movie H.265 50 fps',
        '𝐓𝐑𝐓',
      ];
      for (final input in inputs) {
        final once = normalizeForSearch(input);
        expect(normalizeForSearch(once), once, reason: input);
      }
    });
  });

  group('normalizeChannelName', () {
    const cases = {
      'TR: Show TV HD': 'showtv',
      'TR | SHOW TV FHD': 'showtv',
      '|TR| Show TV': 'showtv',
      '[TR] Show TV': 'showtv',
      'TR - Show TV': 'showtv',
      'TR.Show TV': 'showtv',
      'TR Show TV': 'showtv',
      'Türkiye: Show TV': 'showtv',
      'Show TV': 'showtv',
      'ShowTV': 'showtv',
      'Show-TV (HD)': 'showtv',
      'TRT 1': 'trt1',
      'TRT1 HD': 'trt1',
      'AR: MBC 1': 'mbc1',
      'UK: BBC One': 'bbcone',
      // Country names need an explicit separator; word-like codes too.
      'Italia 1': 'italia1',
      'AL JAZEERA': 'aljazeera',
      'USA Network': 'usanetwork',
      // Never emptied.
      'TR:': 'tr',
    };
    cases.forEach((input, expected) {
      test('$input → $expected', () {
        expect(normalizeChannelName(input), expected);
      });
    });
  });

  group('ftsQuery', () {
    test('builds prefix terms from normalized input', () {
      expect(ftsQuery('sicak kafa'), '"sicak"* "kafa"*');
      expect(ftsQuery('Sıcak Kafa'), '"sicak"* "kafa"*');
      expect(ftsQuery('ŞOW TV FHD'), '"sow"* "tv"*');
    });

    test('blank or unsearchable input gives an empty string', () {
      expect(ftsQuery(''), '');
      expect(ftsQuery('   '), '');
      expect(ftsQuery('"" * - :'), '');
      expect(ftsQuery('HD'), '');
    });

    test('operators and syntax characters are neutralized', () {
      expect(
        ftsQuery('"quoted" AND OR NOT NEAR'),
        '"quoted"* "and"* "or"* "not"* "near"*',
      );
      expect(
        ftsQuery('-show *tv* title:x ^a +b (c OR d)'),
        '"show"* "tv"* "title"* "x"* "a"* "b"* "c"* "or"* "d"*',
      );
      expect(ftsQuery('NEAR(a b, 3)'), '"near"* "a"* "b"* "3"*');
    });

    test('uses at most 16 terms', () {
      final query = ftsQuery(List.generate(40, (i) => 'w$i').join(' '));
      expect(RegExp(r'"\*').allMatches(query).length, 16);
    });

    test('every query is valid FTS5 and finds the expected rows', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      db.execute(
        'CREATE VIRTUAL TABLE search_index USING fts5(normalized, '
        "title UNINDEXED, tokenize = 'unicode61 remove_diacritics 2', "
        "prefix = '2 3')",
      );
      const titles = [
        'Sıcak Kafa',
        'Show TV FHD',
        "Grey's Anatomy",
        'S.W.A.T.',
        'Kış Uykusu',
        'Россия 24',
        'NEAR AND FAR',
      ];
      for (final title in titles) {
        db.execute(
          'INSERT INTO search_index(normalized, title) VALUES (?, ?)',
          [normalizeForSearch(title), title],
        );
      }
      List<String> search(String input) {
        final query = ftsQuery(input);
        if (query.isEmpty) return const [];
        return db
            .select(
              'SELECT title FROM search_index WHERE search_index MATCH ? '
              'ORDER BY rowid',
              [query],
            )
            .map((row) => row['title'] as String)
            .toList();
      }

      expect(search('sic'), ['Sıcak Kafa']);
      expect(search('SICAK kaf'), ['Sıcak Kafa']);
      expect(search('show tv hd'), ['Show TV FHD']);
      expect(search('greys'), ["Grey's Anatomy"]);
      expect(search("grey's"), ["Grey's Anatomy"]);
      expect(search('swat'), ['S.W.A.T.']);
      expect(search('kis uyku'), ['Kış Uykusu']);
      expect(search('россия'), ['Россия 24']);
      expect(search('near'), ['NEAR AND FAR']);
      expect(search('and far'), ['NEAR AND FAR']);

      final hostile = [
        '"',
        '""',
        '"a" OR "b"',
        'a OR b',
        'NOT x',
        'NEAR(a b)',
        'a AND',
        '*',
        'a*b*',
        '-a',
        'col:val',
        'title:sicak',
        '^start',
        '{a b}: c',
        '(((',
        ')))',
        'a + b',
        "'; DROP TABLE search_index; --",
        '🔥🇹🇷 💥',
        '\u0000\u0001',
        'İ ı',
        'x' * 500,
      ];
      for (final input in hostile) {
        expect(() => search(input), returnsNormally, reason: input);
      }
    });
  });

  test('normalizes 100k names quickly', () {
    final names = List.generate(
      100000,
      (i) => 'TR: Şov Kanalı $i HD | Çocuk & Ailə ★ Grey\'s',
    );
    final sw = Stopwatch()..start();
    var total = 0;
    for (final name in names) {
      total += normalizeForSearch(name).length;
    }
    sw.stop();
    // Typically ~100 ms on an M1; the bound only catches pathological
    // slowdowns.
    expect(sw.elapsedMilliseconds, lessThan(3000));
    expect(total, greaterThan(0));
  });
}
