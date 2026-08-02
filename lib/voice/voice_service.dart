import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceStatus { idle, loading, listening, processing, success, error }

class VoiceAIResult {
  final String text;
  final double confidence;
  final bool isFinal;
  final DateTime timestamp;
  const VoiceAIResult({
    required this.text,
    required this.confidence,
    required this.isFinal,
    required this.timestamp,
  });
}

// ─────────────────────────────────────────────────────────────
// VoiceService
// Android  → plugin nativo Kotlin (SpeechRecognizer directo, tiempo real)
// Otros    → speech_to_text como fallback
// ─────────────────────────────────────────────────────────────
class VoiceService {
  static const _method = MethodChannel('com.moneovoice.app/speech_method');
  static const _event  = EventChannel('com.moneovoice.app/speech_event');

  // Fallback (iOS / web / desktop)
  final _stt = SpeechToText();
  bool _sttReady = false;
  String? _sttLocale;

  bool _isActive = false;
  String? _activeLocale;

  // EventChannel — suscrito una sola vez en init()
  StreamSubscription? _nativeSub;

  final _statusCtrl  = StreamController<VoiceStatus>.broadcast();
  final _resultCtrl  = StreamController<VoiceAIResult>.broadcast();
  final _errorCtrl   = StreamController<String>.broadcast();

  Stream<VoiceStatus>   get statusStream   => _statusCtrl.stream;
  Stream<VoiceAIResult> get aiResultStream => _resultCtrl.stream;
  Stream<String>        get errorStream    => _errorCtrl.stream;

  VoiceStatus _status = VoiceStatus.idle;
  void _emit(VoiceStatus s) {
    if (_status != s) { _status = s; _statusCtrl.add(s); }
  }

  bool get _useNative => !kIsWeb && Platform.isAndroid;

  // ── init ───────────────────────────────────────────────────
  Future<void> init() async {
    final perm = await _requestMic();
    if (!perm) return;

    if (_useNative) {
      // Suscribir al EventChannel UNA sola vez aquí
      _nativeSub ??= _event
          .receiveBroadcastStream()
          .cast<Map>()
          .listen(_onNativeEvent, onError: (e) {
            debugPrint('❌ EventChannel error: $e');
          });
      _emit(VoiceStatus.idle);
      return;
    }

    // Fallback STT
    _emit(VoiceStatus.loading);
    try {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && _isActive) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (_isActive && !_stt.isListening) _runSttSession();
            });
          }
        },
        onError: (e) {
          if (e.permanent) {
            _isActive = false;
            _errorCtrl.add(e.errorMsg);
            _emit(VoiceStatus.error);
          }
        },
      );
      if (_sttReady) _sttLocale = await _detectSttLocale();
      _emit(VoiceStatus.idle);
    } catch (e) {
      _errorCtrl.add('$e');
      _emit(VoiceStatus.error);
    }
  }

  // ── startListening ─────────────────────────────────────────
  Future<void> startListening({String? locale}) async {
    if (_isActive) return;
    final perm = await _requestMic();
    if (!perm) return;

    _isActive = true;
    _activeLocale = locale;
    _emit(VoiceStatus.listening);

    if (_useNative) {
      // Asegurar que la suscripción existe (por si acaso)
      _nativeSub ??= _event
          .receiveBroadcastStream()
          .cast<Map>()
          .listen(_onNativeEvent, onError: (_) {});
      final lang = locale ?? PlatformDispatcher.instance.locale.toLanguageTag();
      _method.invokeMethod('start', {'locale': lang});
    } else {
      if (!_sttReady) { await init(); if (!_sttReady) { _isActive = false; return; } }
      await _runSttSession();
    }
  }

  // ── stopListening ──────────────────────────────────────────
  void stopListening() {
    if (!_isActive) return;
    _isActive = false;
    if (_useNative) {
      _method.invokeMethod('stop');
    } else if (_stt.isListening) {
      _stt.stop();
    }
    _emit(VoiceStatus.idle);
  }

  void cancelListening() {
    if (!_isActive) return;
    _isActive = false;
    if (_useNative) {
      _method.invokeMethod('cancel');
    } else {
      _stt.cancel();
    }
    _emit(VoiceStatus.idle);
  }

  // ── Manejador de eventos nativos ───────────────────────────
  void _onNativeEvent(Map event) {
    final type  = event['type']  as String? ?? '';
    final value = event['value'] as String? ?? '';
    switch (type) {
      case 'partial':
        if (!_isActive || value.isEmpty) return;
        _resultCtrl.add(VoiceAIResult(
          text: value, confidence: 0.7,
          isFinal: false, timestamp: DateTime.now(),
        ));
        break;
      case 'final':
        if (!_isActive || value.isEmpty) return;
        _resultCtrl.add(VoiceAIResult(
          text: value, confidence: 1.0,
          isFinal: true, timestamp: DateTime.now(),
        ));
        break;
      case 'status':
        if (value == 'listening' && _isActive) _emit(VoiceStatus.listening);
        break;
      case 'error':
        debugPrint('❌ Native STT: $value');
        if (value == 'speech_not_available') {
          _isActive = false;
          _errorCtrl.add('Reconocimiento de voz no disponible en este dispositivo');
          _emit(VoiceStatus.error);
        }
        break;
    }
  }

  // ── Fallback STT ───────────────────────────────────────────
  Future<void> _runSttSession() async {
    if (!_isActive || _stt.isListening) return;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        if (!_isActive) return;
        final text = r.recognizedWords.trim();
        if (text.isEmpty) return;
        _resultCtrl.add(VoiceAIResult(
          text: text,
          confidence: r.confidence > 0 ? r.confidence : 1.0,
          isFinal: r.finalResult,
          timestamp: DateTime.now(),
        ));
      },
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 2),
      localeId: _activeLocale ?? _sttLocale,
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.dictation,
    );
  }

  Future<String?> _detectSttLocale() async {
    final device = PlatformDispatcher.instance.locale;
    final list   = await _stt.locales();
    if (list.isEmpty) return null;
    final tag  = device.toLanguageTag().replaceAll('-', '_');
    final lang = device.languageCode.toLowerCase();
    for (final l in list) {
      if (l.localeId.replaceAll('-', '_') == tag) return l.localeId;
    }
    for (final l in list) {
      if (l.localeId.toLowerCase().startsWith(lang)) return l.localeId;
    }
    return null;
  }

  Future<bool> _requestMic() async {
    var perm = await Permission.microphone.status;
    if (perm.isDenied) perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      _errorCtrl.add('Permiso de micrófono denegado');
      _emit(VoiceStatus.error);
      return false;
    }
    return true;
  }

  void dispose() {
    _nativeSub?.cancel();
    if (!_useNative) _stt.cancel();
    _statusCtrl.close();
    _resultCtrl.close();
    _errorCtrl.close();
  }
}
