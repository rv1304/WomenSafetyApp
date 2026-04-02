import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice-activated keyword detection using on-device speech_to_text.
/// No audio is recorded or uploaded — text stream is checked locally then discarded.
class VoiceDetectionService {
  static final VoiceDetectionService _instance =
      VoiceDetectionService._internal();
  factory VoiceDetectionService() => _instance;
  VoiceDetectionService._internal();

  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  Timer? _restartTimer;
  VoidCallback? onTrigger;

  bool get isListening => _isListening;

  // ---------------------------------------------------------------------------
  // DEFAULT TRIGGER WORDS (pre-loaded, multilingual)
  // ---------------------------------------------------------------------------
  static const List<String> defaultKeywords = [
    'help',
    'save me',
    'bachao',
    'police',
    'attack',
    'leave me',
    'chod do',
    'madad',
    'emergency',
    'danger',
  ];

  // ---------------------------------------------------------------------------
  // START LISTENING
  // ---------------------------------------------------------------------------
  Future<bool> startListening({VoidCallback? onKeywordDetected}) async {
    onTrigger = onKeywordDetected;

    if (!_isInitialized) {
      _isInitialized = await _stt.initialize(
        onError: (e) {
          debugPrint('[Voice] STT error: $e');
          // Auto-restart on error if we should still be listening
          if (_isListening) _scheduleRestart();
        },
        onStatus: (status) {
          debugPrint('[Voice] STT status: $status');
          if (status == 'done' && _isListening) _scheduleRestart();
        },
      );
    }

    if (!_isInitialized) {
      debugPrint('[Voice] STT not available on this device');
      return false;
    }

    await _listen();
    return true;
  }

  // ---------------------------------------------------------------------------
  // STOP LISTENING
  // ---------------------------------------------------------------------------
  Future<void> stopListening() async {
    _isListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    await _stt.stop();
    debugPrint('[Voice] Stopped listening');
  }

  // ---------------------------------------------------------------------------
  // TOGGLE
  // ---------------------------------------------------------------------------
  Future<bool> toggle({VoidCallback? onKeywordDetected}) async {
    if (_isListening) {
      await stopListening();
      return false;
    } else {
      return await startListening(onKeywordDetected: onKeywordDetected);
    }
  }

  // ---------------------------------------------------------------------------
  // CUSTOM KEYWORDS — stored in SharedPreferences
  // ---------------------------------------------------------------------------
  Future<List<String>> getCustomKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('voice_custom_keywords') ?? [];
  }

  Future<void> addCustomKeyword(String keyword) async {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('voice_custom_keywords') ?? [];
    if (!list.contains(kw)) {
      list.add(kw);
      await prefs.setStringList('voice_custom_keywords', list);
    }
  }

  Future<void> removeCustomKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('voice_custom_keywords') ?? [];
    list.remove(keyword.toLowerCase());
    await prefs.setStringList('voice_custom_keywords', list);
  }

  Future<List<String>> getAllKeywords() async {
    final custom = await getCustomKeywords();
    return [...defaultKeywords, ...custom];
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE — save/load enabled state
  // ---------------------------------------------------------------------------
  Future<void> saveEnabledState(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_detection_enabled', enabled);
  }

  Future<bool> loadEnabledState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('voice_detection_enabled') ?? false;
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — internal listen loop
  // ---------------------------------------------------------------------------
  Future<void> _listen() async {
    _isListening = true;
    await _stt.listen(
      onResult: (result) async {
        final text = result.recognizedWords.toLowerCase();
        debugPrint('[Voice] Heard: "$text"');
        final allKeywords = await getAllKeywords();
        for (final kw in allKeywords) {
          if (text.contains(kw)) {
            debugPrint('[Voice] ⚡ KEYWORD DETECTED: "$kw"');
            onTrigger?.call();
            return;
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 2), () async {
      if (_isListening) await _listen();
    });
  }
}
