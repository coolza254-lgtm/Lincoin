/// Deterministic hashing that gives identical results on every platform
/// (VM, AOT, web), so anything derived from it can be replayed exactly.
library;

const int _mask32 = 0xFFFFFFFF;

/// 32-bit multiply modulo 2^32 without relying on 64-bit integer overflow,
/// which behaves differently when compiled to JavaScript.
int _mul32(int a, int b) {
  final aHi = (a >> 16) & 0xFFFF;
  final aLo = a & 0xFFFF;
  return ((aLo * b) + (((aHi * b) & 0xFFFF) << 16)) & _mask32;
}

/// FNV-1a 32-bit hash of the UTF-16 code units of [input].
int fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash ^= unit & 0xFF;
    hash = _mul32(hash, 0x01000193);
    hash ^= (unit >> 8) & 0xFF;
    hash = _mul32(hash, 0x01000193);
  }
  return hash;
}

/// A value in [0, 1) derived only from [key].
double unitFromKey(String key) => fnv1a32(key) / 4294967296.0;
