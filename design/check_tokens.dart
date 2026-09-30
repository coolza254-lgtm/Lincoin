// Checks design/tokens.json: every theme defines the same colour tokens and
// every listed text/background pair meets its contrast ratio (WCAG).
// Usage: dart run design/check_tokens.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

double _lum(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  double ch(int c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * ch((v >> 16) & 0xFF) + 0.7152 * ch((v >> 8) & 0xFF) + 0.0722 * ch(v & 0xFF);
}

double contrast(String a, String b) {
  final la = _lum(a), lb = _lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  final path = '${File.fromUri(Platform.script).parent.path}/tokens.json';
  final t = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final themes = t['themes'] as Map<String, dynamic>;
  final pairs = (t['contrastPairs'] as List).cast<List<dynamic>>();
  var failures = 0;
  Set<String>? keys;
  for (final MapEntry(key: name, value: theme) in themes.entries) {
    final colors = (theme['colors'] as Map).cast<String, String>();
    keys ??= colors.keys.toSet();
    if (!keys.containsAll(colors.keys) || !colors.keys.toSet().containsAll(keys)) {
      print('FAIL $name: token set differs from other themes');
      failures++;
    }
    for (final p in pairs) {
      final fg = p[0] as String, bg = p[1] as String, need = (p[2] as num).toDouble();
      final c = contrast(colors[fg]!, colors[bg]!);
      final ok = c >= need;
      if (!ok) failures++;
      print('${ok ? 'ok  ' : 'FAIL'} $name ${'$fg/$bg'.padRight(22)} ${c.toStringAsFixed(2)} (need $need)');
    }
  }
  if (failures > 0) {
    print('$failures problem(s)');
    exit(1);
  }
  print('All themes pass.');
}
