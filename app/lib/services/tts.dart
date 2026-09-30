import 'package:flutter_tts/flutter_tts.dart';

/// Japanese text-to-speech from the phone's own engine (works offline if a
/// Japanese voice is installed).
class Tts {
  final FlutterTts _tts = FlutterTts();
  bool? _available;

  Future<bool> available() async {
    if (_available != null) return _available!;
    try {
      final r = await _tts.isLanguageAvailable('ja-JP');
      _available = r == true || r == 1;
      if (_available!) {
        await _tts.setLanguage('ja-JP');
        await _tts.setSpeechRate(0.45);
      }
    } on Object {
      _available = false;
    }
    return _available!;
  }

  /// Speaks [text]; returns false when no Japanese voice is available.
  Future<bool> speak(String text) async {
    if (!await available()) return false;
    try {
      await _tts.stop();
      await _tts.speak(text);
      return true;
    } on Object {
      return false;
    }
  }

  void dispose() {
    _tts.stop().ignore();
  }
}
