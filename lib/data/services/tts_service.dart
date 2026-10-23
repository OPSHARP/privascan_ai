import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsPlaybackState { stopped, playing, paused }

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  TtsPlaybackState _state = TtsPlaybackState.stopped;
  double _speechRate = 0.5; // FlutterTts standard rate

  final ValueNotifier<TtsPlaybackState> stateNotifier =
      ValueNotifier<TtsPlaybackState>(TtsPlaybackState.stopped);

  bool _isInitialized = false;

  TtsPlaybackState get state => _state;
  double get speechRate => _speechRate;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _flutterTts.setStartHandler(() {
      _state = TtsPlaybackState.playing;
      stateNotifier.value = _state;
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsPlaybackState.stopped;
      stateNotifier.value = _state;
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsPlaybackState.stopped;
      stateNotifier.value = _state;
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsPlaybackState.paused;
      stateNotifier.value = _state;
    });

    _flutterTts.setContinueHandler(() {
      _state = TtsPlaybackState.playing;
      stateNotifier.value = _state;
    });

    _flutterTts.setErrorHandler((dynamic msg) {
      _state = TtsPlaybackState.stopped;
      stateNotifier.value = _state;
    });

    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> speak(String text, {String? languageCode}) async {
    if (text.trim().isEmpty) return;
    await init();
    if (languageCode != null && languageCode.isNotEmpty) {
      try {
        await _flutterTts.setLanguage(languageCode);
      } catch (_) {}
    }
    _state = TtsPlaybackState.playing;
    stateNotifier.value = _state;
    await _flutterTts.speak(text);
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _state = TtsPlaybackState.paused;
    stateNotifier.value = _state;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsPlaybackState.stopped;
    stateNotifier.value = _state;
  }

  Future<void> setRate(double rate) async {
    _speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  void dispose() {
    _flutterTts.stop();
  }
}
