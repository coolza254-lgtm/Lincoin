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

  int _run = 0;

  /// Speaks [texts] one after another (word, then example). A newer call
  /// cancels the rest of an older one. False when there is no Japanese
  /// voice.
  Future<bool> speakAll(List<String> texts) async {
    if (!await available()) return false;
    final run = ++_run;
    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      for (final (i, t) in texts.indexed) {
        if (run != _run) break;
        if (i > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
        if (run != _run) break;
        await _tts.speak(t);
      }
      return true;
    } on Object {
      return false;
    }
  }

  /// Stops speaking (and any queued text).
  void stop() {
    _run++;
    _tts.stop().ignore();
  }

  void dispose() {
    _tts.stop().ignore();
  }
}
