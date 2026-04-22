import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
// ignore: uri_does_not_exist
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wrapper for speech-to-text: permission, init, listen, stop.
/// Used for voice input in AI food description and (later) image clarification.
class SpeechToTextService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static String _transcript = '';
  static bool _isListening = false;
  static void Function(String)? _onComplete;
  static void Function(String)? _onPartial;
  static Timer? _autoStopTimer;

  static bool get isListening => _isListening;

  /// One-time init. Call before first use (e.g. when user opens AI food modal).
  static Future<bool> initialize() async {
    try {
      return await _speech.initialize(
        onError: (error) => _onError(error),
        onStatus: (status) => _onStatus(status),
      );
    } catch (e) {
      print('SpeechToTextService.initialize error: $e');
      return false;
    }
  }

  static void _onError(dynamic error) {
    print('SpeechToTextService error: $error');
  }

  static void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (!_isListening) return;
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      _isListening = false;
      final onComplete = _onComplete;
      _onComplete = null;
      _onPartial = null;
      onComplete?.call(_transcript);
    }
  }

  /// Request microphone permission. Call before startListening.
  static Future<bool> requestPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  /// Start listening. Updates [onPartial] with live transcript; calls [onComplete] with final text when stopped.
  /// Call [stopListening] to finish, or listening auto-stops after [listenFor] (default 30s).
  static Future<bool> startListening({
    void Function(String)? onPartial,
    required void Function(String) onComplete,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (_isListening) return false;

    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    final initialized = await initialize();
    if (!initialized) return false;

    _transcript = '';
    _onPartial = onPartial;
    _onComplete = onComplete;
    _isListening = true;
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(listenFor, () {
      stopListening();
    });

    try {
      final didStart = await _speech.listen(
        onResult: (result) {
          _transcript = result.recognizedWords;
          _onPartial?.call(_transcript);
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
      );

      if (!didStart) {
        _autoStopTimer?.cancel();
        _autoStopTimer = null;
        _isListening = false;
        _onComplete?.call('');
        _onComplete = null;
        return false;
      }

      return true;
    } catch (e) {
      print('SpeechToTextService.startListening error: $e');
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      _isListening = false;
      _onComplete?.call('');
      _onComplete = null;
      return false;
    }
  }

  /// Stop listening and deliver final transcript via the [onComplete] callback passed to [startListening].
  static Future<void> stopListening() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (e) {
      print('SpeechToTextService.stopListening error: $e');
    }
    _isListening = false;
    final onComplete = _onComplete;
    _onComplete = null;
    _onPartial = null;
    onComplete?.call(_transcript);
  }

  /// Current transcript (partial or final). Useful for UI.
  static String get currentTranscript => _transcript;
}
