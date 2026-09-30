/// Thai names for JMdict part-of-speech codes. Kept beside the ARB files
/// because they label content rather than UI.
const Map<String, String> posThai = {
  'n': 'คำนาม',
  'pn': 'สรรพนาม',
  'adj-i': 'คุณศัพท์ -い',
  'adj-ix': 'คุณศัพท์ -い',
  'adj-na': 'คุณศัพท์ -な',
  'adj-no': 'คำนาม (+の)',
  'adj-pn': 'คำขยายนาม',
  'adj-t': 'คุณศัพท์ -と',
  'adj-f': 'คำขยายนาม',
  'adv': 'คำวิเศษณ์',
  'adv-to': 'คำวิเศษณ์ (+と)',
  'aux': 'คำช่วย',
  'aux-v': 'กริยานุเคราะห์',
  'aux-adj': 'คุณศัพท์นุเคราะห์',
  'conj': 'คำเชื่อม',
  'cop': 'คำเชื่อมประโยค (です/だ)',
  'ctr': 'ลักษณนาม',
  'exp': 'สำนวน',
  'int': 'คำอุทาน',
  'num': 'ตัวเลข',
  'pref': 'คำเติมหน้า',
  'suf': 'คำเติมท้าย',
  'prt': 'คำช่วย',
  'vs': 'คำนาม (+する)',
  'vs-i': 'กริยา する',
  'vs-s': 'กริยา する',
  'vk': 'กริยา 来る',
  'vz': 'กริยา',
  'vi': 'อกรรมกริยา',
  'vt': 'สกรรมกริยา',
};

String posLabel(String code) {
  if (posThai.containsKey(code)) return posThai[code]!;
  if (code.startsWith('v5') ||
      code.startsWith('v1') ||
      code.startsWith('v2') ||
      code.startsWith('v4')) {
    return code.startsWith('v1') ? 'กริยากลุ่ม 2' : 'กริยากลุ่ม 1';
  }
  return code;
}

/// Readable labels for a word's POS list: duplicates and labels implied by
/// another one removed ("คำนาม (+する)" already says noun; transitivity of a
/// する-noun adds little), at most [max] of them.
List<String> posLabels(Iterable<String> codes, {int max = 3}) {
  final all = codes.toSet();
  final implied = {
    if (all.contains('vs')) ...['n', 'vt', 'vi'],
    if (all.contains('n') || all.contains('vs')) 'adj-no',
  };
  final out = {
    for (final c in codes)
      if (!implied.contains(c)) posLabel(c),
  }.toList();
  return out.length > max ? out.sublist(0, max) : out;
}
