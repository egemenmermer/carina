/// Deterministic pseudo-random numbers for the mock catalog.
///
/// `dart:math`'s `Random(seed)` is not guaranteed to produce the same
/// sequence on every SDK version and platform, and the mock catalog must be
/// identical on macOS and on the Windows CI runner. This file uses a Weyl
/// sequence mixed with a 32-bit avalanche hash ("lowbias32"), which only
/// needs 32-bit arithmetic and is stable everywhere the Dart VM runs.
library;

const int _mask32 = 0xFFFFFFFF;

/// 32-bit avalanche hash (lowbias32 by Chris Wellons).
int mix32(int x) {
  var v = x & _mask32;
  v ^= v >>> 16;
  v = (v * 0x7feb352d) & _mask32;
  v ^= v >>> 15;
  v = (v * 0x846ca68b) & _mask32;
  v ^= v >>> 16;
  return v;
}

/// Combines up to four integers into one 32-bit hash. Used to derive stable
/// per-item seeds (for example `mixHash(channelSeed, dayNumber)`).
int mixHash(int a, [int b = 0, int c = 0, int d = 0]) {
  var h = mix32(a ^ 0x9E3779B9);
  h = mix32(h ^ (b & _mask32) ^ 0x85EBCA6B);
  h = mix32(h ^ (c & _mask32) ^ 0xC2B2AE35);
  h = mix32(h ^ (d & _mask32) ^ 0x27D4EB2F);
  return h;
}

/// Stable 32-bit hash of a string (FNV-1a over UTF-16 code units).
int hashString(String s) {
  var h = 0x811C9DC5;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 0x01000193) & _mask32;
  }
  return mix32(h);
}

/// Small deterministic random generator.
class MockRandom {
  MockRandom(int seed) : _state = mix32(seed);

  int _state;

  /// Next 32-bit unsigned value.
  int nextUint32() {
    _state = (_state + 0x9E3779B9) & _mask32;
    return mix32(_state);
  }

  /// Uniform integer in `[0, max)`. [max] must be positive.
  int nextInt(int max) {
    assert(max > 0);
    if (max <= 1) return 0;
    return nextUint32() % max;
  }

  /// Uniform integer in `[min, maxInclusive]`.
  int range(int min, int maxInclusive) {
    if (maxInclusive <= min) return min;
    return min + nextInt(maxInclusive - min + 1);
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  /// True with probability [p].
  bool chance(double p) => nextDouble() < p;

  /// One random element of [items] (must not be empty).
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// One element of [items] chosen with the given integer [weights].
  T weighted<T>(List<T> items, List<int> weights) {
    assert(items.length == weights.length && items.isNotEmpty);
    var total = 0;
    for (final w in weights) {
      total += w;
    }
    var roll = nextInt(total);
    for (var i = 0; i < items.length; i++) {
      roll -= weights[i];
      if (roll < 0) return items[i];
    }
    return items.last;
  }

  /// [count] distinct elements of [items] (fewer if [items] is shorter).
  List<T> sample<T>(List<T> items, int count) {
    if (count >= items.length) return shuffled(items);
    final picked = <int>{};
    final out = <T>[];
    while (out.length < count) {
      final i = nextInt(items.length);
      if (picked.add(i)) out.add(items[i]);
    }
    return out;
  }

  /// A shuffled copy of [items] (Fisher–Yates).
  List<T> shuffled<T>(List<T> items) {
    final out = List<T>.of(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }
}
