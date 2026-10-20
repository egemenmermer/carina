import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/text/quality.dart';

void main() {
  // raw name → (display name, badges)
  const cases = <String, (String, List<String>)>{
    // Plain suffix tokens.
    'TRT 1 HD': ('TRT 1', ['HD']),
    'Show TV FHD': ('Show TV', ['FHD']),
    'Kanal D SD': ('Kanal D', ['SD']),
    'UHD Test 4K': ('Test', ['4K']),
    'Fox 4K': ('Fox', ['4K']),
    'Sky Sport 8K': ('Sky Sport', ['8K']),
    // Case and position.
    'Show TV hd': ('Show TV', ['HD']),
    'show tv Fhd': ('show tv', ['FHD']),
    'HD Show TV': ('Show TV', ['HD']),
    'Show HD TV': ('Show TV', ['HD']),
    // Brackets and separators.
    '[FHD] Show TV': ('Show TV', ['FHD']),
    'Show TV (HD)': ('Show TV', ['HD']),
    'Show TV [FHD|HEVC]': ('Show TV', ['FHD', 'H265']),
    'Show TV | HD': ('Show TV', ['HD']),
    'Show TV - FHD': ('Show TV', ['FHD']),
    'FHD | Show TV': ('Show TV', ['FHD']),
    'Show TV - HD - TR': ('Show TV - TR', ['HD']),
    'Show TV (HD) - Yedek': ('Show TV - Yedek', ['HD']),
    'Show TV (HD Yedek)': ('Show TV (Yedek)', ['HD']),
    'Show-HD-TV': ('Show-TV', ['HD']),
    'TR | Show TV [FHD]': ('TR | Show TV', ['FHD']),
    'TR: Show TV HD': ('TR: Show TV', ['HD']),
    'Show TV 【HD】': ('Show TV', ['HD']),
    // Synonyms and normalization.
    'Show TV FULL HD': ('Show TV', ['FHD']),
    'Show TV Full-HD': ('Show TV', ['FHD']),
    'Show TV FULLHD': ('Show TV', ['FHD']),
    'Show TV Ultra HD': ('Show TV', ['4K']),
    'Show TV UHD': ('Show TV', ['4K']),
    'Show TV 2160P': ('Show TV', ['4K']),
    'Show TV 1080p': ('Show TV', ['FHD']),
    'Show TV 720P': ('Show TV', ['HD']),
    'Show TV 576i': ('Show TV', ['SD']),
    'Show TV HEVC': ('Show TV', ['H265']),
    'Show TV H.265': ('Show TV', ['H265']),
    'Show TV h265': ('Show TV', ['H265']),
    'Show TV x265': ('Show TV', ['H265']),
    'Show TV 50FPS': ('Show TV', ['50FPS']),
    'Show TV 60fps': ('Show TV', ['60FPS']),
    'Show TV 50 FPS': ('Show TV', ['50FPS']),
    'Show TV 1080p50': ('Show TV', ['FHD', '50FPS']),
    'Show TV HDR': ('Show TV', ['HDR']),
    // Several tokens: one resolution (the highest), fixed order.
    'Show TV FHD H.265 50FPS': ('Show TV', ['FHD', 'H265', '50FPS']),
    'Show TV 50FPS HEVC UHD HDR': ('Show TV', ['4K', 'HDR', 'H265', '50FPS']),
    'Show TV SD/HD': ('Show TV', ['HD']),
    'Show TV HD HD': ('Show TV', ['HD']),
    'Show TV 4K UHD': ('Show TV', ['4K']),
    // Small capitals and superscripts used by some providers.
    'TRT 1 ᴴᴰ': ('TRT 1', ['HD']),
    'TRT 1 ᶠᴴᴰ': ('TRT 1', ['FHD']),
    'beIN Sports ʜᴅ': ('beIN Sports', ['HD']),
    // `+` after a resolution goes with it; `+` in a name stays.
    'TRT 1 HD+': ('TRT 1', ['HD']),
    'Canal+ HD': ('Canal+', ['HD']),
    // Words that merely contain a token are not tokens.
    'HDTV Kanal': ('HDTV Kanal', []),
    'SHD Kanal': ('SHD Kanal', []),
    'Hdfilm': ('Hdfilm', []),
    '4Kids TV': ('4Kids TV', []),
    'Full Moon TV': ('Full Moon TV', []),
    'Show TV H.264': ('Show TV H.264', []),
    'Kanal 50': ('Kanal 50', []),
    // No tokens.
    'Haber Canlı HLS': ('Haber Canlı HLS', []),
    'Çocuk Kilitli': ('Çocuk Kilitli', []),
    '  Show   TV  ': ('Show TV', []),
    '': ('', []),
    // Only tokens: the name is kept and no badge is invented.
    '4K UHD': ('4K UHD', []),
    'HD': ('HD', []),
  };

  cases.forEach((raw, expected) {
    test('"$raw" → "${expected.$1}" ${expected.$2}', () {
      final parsed = parseQuality(raw);
      expect(parsed.displayName, expected.$1);
      expect(parsed.badges, expected.$2);
    });
  });

  test('has at least 25 cases', () {
    expect(cases.length, greaterThanOrEqualTo(25));
  });
}
