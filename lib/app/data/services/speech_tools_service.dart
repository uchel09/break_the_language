import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/speaking_assessment_model.dart';

/// Handles microphone recording, amplitude capture, speech-to-text, and TTS.
/// Safely handles platform differences across Android, Windows, Web, and tests.
class SpeechToolsService extends GetxService {
  AudioRecorder? _recorder;
  FlutterTts? _tts;
  SpeechToText? _stt;
  bool _sttInitialized = false;
  final Stopwatch _recordingWatch = Stopwatch();
  final List<double> _amplitudeSamples = <double>[];
  StreamSubscription<Amplitude>? _ampSub;

  final isRecording = false.obs;
  final isListeningStt = false.obs;
  final recognizedText = ''.obs;
  final sttAvailable = false.obs;
  final statusNote = ''.obs;

  AudioRecorder _ensureRecorder() {
    _recorder ??= AudioRecorder();
    return _recorder!;
  }

  FlutterTts _ensureTts() {
    _tts ??= FlutterTts();
    return _tts!;
  }

  Future<bool> _ensureStt() async {
    if (_sttInitialized) return sttAvailable.value;
    try {
      _stt ??= SpeechToText();
      final ok = await _stt!.initialize(
        onStatus: (status) {
          isListeningStt.value = status == 'listening';
        },
        onError: (err) {
          isListeningStt.value = false;
          statusNote.value = 'STT: ${err.errorMsg}';
        },
      );
      sttAvailable.value = ok;
      _sttInitialized = true;
      return ok;
    } catch (_) {
      sttAvailable.value = false;
      _sttInitialized = true;
      return false;
    }
  }

  Future<bool> startRecording({
    required String tag,
    bool enableStt = true,
    void Function(String transcript)? onTranscript,
  }) async {
    recognizedText.value = '';
    statusNote.value = '';

    try {
      final recorder = _ensureRecorder();
      final allowed = await recorder.hasPermission();
      if (!allowed) {
        statusNote.value = 'Izin mikrofon belum diberikan.';
        return false;
      }

      final targetPath = await _buildRecordingPath(tag);
      final config = _pickRecordConfig();
      _amplitudeSamples.clear();
      await _ampSub?.cancel();
      _recordingWatch
        ..reset()
        ..start();
      await recorder.start(config, path: targetPath);
      isRecording.value = true;

      try {
        _ampSub = recorder
            .onAmplitudeChanged(const Duration(milliseconds: 80))
            .listen((amp) {
          _amplitudeSamples.add(amp.current);
        }, onError: (_) {});
      } catch (_) {}

      if (enableStt) {
        unawaited(_startSttOptional(onTranscript: onTranscript));
      }
      return true;
    } catch (e) {
      _recordingWatch.stop();
      await _ampSub?.cancel();
      _ampSub = null;
      isRecording.value = false;
      statusNote.value = 'Gagal membuka mikrofon: $e';
      return false;
    }
  }

  Future<void> _startSttOptional({
    void Function(String transcript)? onTranscript,
  }) async {
    try {
      final ok = await _ensureStt();
      if (!ok || _stt == null) return;
      await _stt!.listen(
        onResult: (result) {
          recognizedText.value = result.recognizedWords;
          onTranscript?.call(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: 'en_US',
          listenMode: ListenMode.dictation,
        ),
      );
      isListeningStt.value = true;
    } catch (_) {
      isListeningStt.value = false;
    }
  }

  Future<RecordingCapture> stopRecordingWithCapture() async {
    _recordingWatch.stop();
    final elapsed = _recordingWatch.elapsed;
    final capturedSamples = List<double>.from(_amplitudeSamples);

    try {
      await _ampSub?.cancel();
      _ampSub = null;
    } catch (_) {}

    try {
      if (_stt != null && _stt!.isListening) {
        await _stt!.stop();
      }
    } catch (_) {}
    isListeningStt.value = false;

    String? savedPath;
    try {
      if (_recorder != null && isRecording.value) {
        savedPath = await _recorder!.stop();
      }
    } catch (e) {
      statusNote.value = 'Gagal menyimpan rekaman: $e';
    }
    isRecording.value = false;

    return RecordingCapture(
      filePath: savedPath,
      transcript: recognizedText.value,
      elapsed: elapsed,
      amplitudeDbfs: capturedSamples,
    );
  }

  Future<String?> stopRecording() async {
    final capture = await stopRecordingWithCapture();
    return capture.filePath;
  }

  Future<void> speakPrompt(String text, {double rate = 0.48}) async {
    if (text.trim().isEmpty) return;
    try {
      final tts = _ensureTts();
      await tts.stop();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(rate);
      await tts.setVolume(1.0);
      await tts.speak(text);
    } catch (_) {}
  }

  Future<void> stopTts() async {
    try {
      if (_tts != null) {
        await _tts!.stop();
      }
    } catch (_) {}
  }

  RecordConfig _pickRecordConfig() {
    if (kIsWeb) {
      return const RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 64000,
        sampleRate: 48000,
        numChannels: 1,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );
    }
    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 96000,
      sampleRate: 44100,
      numChannels: 1,
    );
  }

  Future<String> _buildRecordingPath(String tag) async {
    if (kIsWeb) {
      return '${tag}_${DateTime.now().millisecondsSinceEpoch}.webm';
    }
    final dir = await getTemporaryDirectory();
    final isWav = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final ext = isWav ? 'wav' : 'm4a';
    final cleanTag = tag.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${dir.path}/engdestroying_${cleanTag}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  @override
  void onClose() {
    _recordingWatch.stop();
    unawaited(_ampSub?.cancel() ?? Future.value());
    unawaited(stopRecording());
    unawaited(stopTts());
    unawaited(_recorder?.dispose() ?? Future.value());
    super.onClose();
  }
}
