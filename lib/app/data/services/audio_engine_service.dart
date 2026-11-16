import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/lesson_topic_model.dart';

/// Manages three independent audio channels:
/// 1) Voice/Dialogue channel (native Normal, native Slow, or user recording)
/// 2) Continuous looping background ambience (keeps running across turns)
/// 3) Foreground SFX channel (door chime, book pat, etc.)
class AudioEngineService extends GetxService {
  AudioPlayer? _voicePlayer;
  AudioPlayer? _ambiencePlayer;
  AudioPlayer? _sfxPlayer;

  final isPlayingVoice = false.obs;
  final isWaitingUserTurn = false.obs;
  final isAmbienceActive = false.obs;
  final ambienceVolume = 0.25.obs;
  final activeLineIndex = (-1).obs;
  final playbackStatus = ''.obs;

  int _voiceSessionToken = 0;

  AudioPlayer _ensureVoicePlayer() {
    if (_voicePlayer != null) return _voicePlayer!;
    final player = AudioPlayer(playerId: 'voice_channel');
    unawaited(player.setReleaseMode(ReleaseMode.stop));
    _voicePlayer = player;
    return player;
  }

  AudioPlayer _ensureAmbiencePlayer() {
    if (_ambiencePlayer != null) return _ambiencePlayer!;
    final player = AudioPlayer(playerId: 'ambience_channel');
    unawaited(player.setReleaseMode(ReleaseMode.loop));
    _ambiencePlayer = player;
    return player;
  }

  AudioPlayer _ensureSfxPlayer() {
    if (_sfxPlayer != null) return _sfxPlayer!;
    final player = AudioPlayer(playerId: 'sfx_channel');
    unawaited(player.setReleaseMode(ReleaseMode.stop));
    _sfxPlayer = player;
    return player;
  }

  Future<void> preloadTopicAssets(TopicData data) async {
    final paths = <String>{
      if (data.audioAssets.ambienceLoop.isNotEmpty)
        data.audioAssets.ambienceLoop,
      if (data.audioAssets.sfxDoorChime.isNotEmpty)
        data.audioAssets.sfxDoorChime,
      if (data.audioAssets.sfxBookPat.isNotEmpty) data.audioAssets.sfxBookPat,
      for (final line in data.dialogue.take(4)) line.audio,
    };
    for (final path in paths) {
      try {
        await AudioCache.instance.loadPath(path);
      } catch (_) {}
    }
  }

  void clearStatus() {
    playbackStatus.value = '';
  }

  String _formatAudioError(Object error) {
    final raw = error.toString();
    if (raw.contains('Failed to fetch') || raw.contains('Connection refused')) {
      return 'Gagal mengambil file audio: server lokal terhenti/offline.';
    }
    if (raw.contains('NotAllowedError')) {
      return 'Browser menahan suara otomatis. Pastikan tab tidak di-mute lalu ketuk Play lagi.';
    }
    return 'Audio error: $raw';
  }

  Future<void> startAmbience(String assetPath, {double? volume}) async {
    if (assetPath.isEmpty) return;
    if (volume != null) {
      ambienceVolume.value = volume.clamp(0.0, 1.0);
    }
    try {
      final player = _ensureAmbiencePlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource(assetPath),
        volume: ambienceVolume.value,
      );
      isAmbienceActive.value = true;
    } catch (e) {
      playbackStatus.value = _formatAudioError(e);
    }
  }

  Future<void> stopAmbience() async {
    try {
      if (_ambiencePlayer != null) {
        await _ambiencePlayer!.stop();
      }
    } catch (_) {}
    isAmbienceActive.value = false;
  }

  Future<void> setAmbienceVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    ambienceVolume.value = clamped;
    try {
      if (_ambiencePlayer != null) {
        await _ambiencePlayer!.setVolume(clamped);
      }
    } catch (_) {}
  }

  Future<void> playSfx(String assetPath, {double volume = 0.85}) async {
    if (assetPath.isEmpty) return;
    try {
      final player = _ensureSfxPlayer();
      if (player.state == PlayerState.playing) {
        await player.stop();
      }
      await player.play(
        AssetSource(assetPath),
        volume: volume.clamp(0.0, 1.0),
      );
    } catch (e) {
      playbackStatus.value = _formatAudioError(e);
    }
  }

  Future<void> stopVoice() async {
    _voiceSessionToken++;
    isPlayingVoice.value = false;
    isWaitingUserTurn.value = false;
    activeLineIndex.value = -1;
    try {
      if (_voicePlayer != null) {
        await _voicePlayer!.stop();
      }
      if (_sfxPlayer != null) {
        await _sfxPlayer!.stop();
      }
    } catch (_) {}
  }

  Future<void> stopAll() async {
    await stopVoice();
    await stopAmbience();
  }

  Future<void> playSingleAsset(String assetPath, {int lineIndex = -1}) async {
    final token = ++_voiceSessionToken;
    activeLineIndex.value = lineIndex;
    isPlayingVoice.value = true;
    final completed = await playAudioSource(
      AssetSource(assetPath),
      token: token,
    );
    if (completed && token == _voiceSessionToken) {
      isPlayingVoice.value = false;
      activeLineIndex.value = -1;
    }
  }

  Future<void> playRecordedAudio(String pathOrUrl, {int lineIndex = -1}) async {
    final token = ++_voiceSessionToken;
    activeLineIndex.value = lineIndex;
    isPlayingVoice.value = true;
    final source = kIsWeb ? UrlSource(pathOrUrl) : DeviceFileSource(pathOrUrl);
    final completed = await playAudioSource(source, token: token);
    if (completed && token == _voiceSessionToken) {
      isPlayingVoice.value = false;
      activeLineIndex.value = -1;
    }
  }

  /// Plays all dialogue lines sequentially.
  /// Slow mode plays native pre-generated `line.audioSlow` files without digital warping.
  Future<void> playDialogueSequence({
    required List<DialogueLine> lines,
    required bool slow,
    required bool withRealSituation,
    required AudioAssetsInfo assetsInfo,
    int startFromIndex = 0,
    void Function(int index)? onLineChanged,
  }) async {
    final token = ++_voiceSessionToken;
    isPlayingVoice.value = true;

    if (withRealSituation && assetsInfo.ambienceLoop.isNotEmpty) {
      await startAmbience(assetsInfo.ambienceLoop);
    } else if (!withRealSituation && isAmbienceActive.value) {
      await stopAmbience();
    }

    for (var i = startFromIndex; i < lines.length; i++) {
      if (token != _voiceSessionToken) return;
      final line = lines[i];
      activeLineIndex.value = line.index;
      onLineChanged?.call(line.index);

      if (withRealSituation && line.sfxBefore != null) {
        await _triggerCueSfx(line.sfxBefore!, assetsInfo);
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (token != _voiceSessionToken) return;
      }

      final assetPath = slow ? line.audioSlow : line.audio;
      final completed = await playAudioSource(
        AssetSource(assetPath),
        token: token,
      );
      if (!completed || token != _voiceSessionToken) {
        if (token == _voiceSessionToken) {
          isPlayingVoice.value = false;
          activeLineIndex.value = -1;
        }
        return;
      }

      await Future<void>.delayed(
        Duration(milliseconds: slow ? 360 : 240),
      );
    }

    if (token == _voiceSessionToken) {
      isPlayingVoice.value = false;
      activeLineIndex.value = -1;
      if (withRealSituation) {
        await stopAmbience();
      }
    }
  }

  /// Plays a complete interactive role-play duet combining AI character lines
  /// and the user's recorded voice turns over optional continuous ambience.
  Future<void> playRolePlayDuet({
    required List<DialogueLine> lines,
    required String userRoleId,
    required Map<int, String> userRecordings,
    required AudioAssetsInfo assetsInfo,
    required bool useAmbience,
    void Function(int index)? onTurnChanged,
  }) async {
    final token = ++_voiceSessionToken;
    isPlayingVoice.value = true;

    if (useAmbience && assetsInfo.ambienceLoop.isNotEmpty && !isAmbienceActive.value) {
      await startAmbience(assetsInfo.ambienceLoop);
    }

    for (final line in lines) {
      if (token != _voiceSessionToken) return;
      activeLineIndex.value = line.index;
      onTurnChanged?.call(line.index);

      if (useAmbience && line.sfxBefore != null) {
        await _triggerCueSfx(line.sfxBefore!, assetsInfo);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (token != _voiceSessionToken) return;
      }

      final recordedPath = userRecordings[line.index];
      final isUserRole = line.speakerId == userRoleId;

      if (isUserRole) {
        if (recordedPath != null && recordedPath.isNotEmpty) {
          isWaitingUserTurn.value = false;
          final userSource = kIsWeb
              ? UrlSource(recordedPath)
              : DeviceFileSource(recordedPath);
          final completed = await playAudioSource(userSource, token: token);
          if (!completed || token != _voiceSessionToken) {
            if (token == _voiceSessionToken) {
              isPlayingVoice.value = false;
              isWaitingUserTurn.value = false;
              activeLineIndex.value = -1;
            }
            return;
          }
        } else {
          // Mute the user's chosen character and give live speaking time.
          isWaitingUserTurn.value = true;
          final turnMs = (((line.durationSec ?? 2.2) + 0.9) * 1000).round();
          var waitedMs = 0;
          while (waitedMs < turnMs) {
            if (token != _voiceSessionToken) {
              isWaitingUserTurn.value = false;
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
            waitedMs += 100;
          }
          isWaitingUserTurn.value = false;
        }
      } else {
        isWaitingUserTurn.value = false;
        final completed = await playAudioSource(
          AssetSource(line.audio),
          token: token,
        );
        if (!completed || token != _voiceSessionToken) {
          if (token == _voiceSessionToken) {
            isPlayingVoice.value = false;
            isWaitingUserTurn.value = false;
            activeLineIndex.value = -1;
          }
          return;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    if (token == _voiceSessionToken) {
      isPlayingVoice.value = false;
      isWaitingUserTurn.value = false;
      activeLineIndex.value = -1;
    }
  }

  Future<void> _triggerCueSfx(String cue, AudioAssetsInfo info) async {
    if (cue == 'door_chime' && info.sfxDoorChime.isNotEmpty) {
      await playSfx(info.sfxDoorChime, volume: 0.78);
    } else if (cue == 'book_pat' && info.sfxBookPat.isNotEmpty) {
      await playSfx(info.sfxBookPat, volume: 0.75);
    }
  }

  @visibleForTesting
  Future<bool> playAudioSource(
    Source source, {
    required int token,
  }) async {
    if (token != _voiceSessionToken) return false;
    playbackStatus.value = '';
    try {
      final player = _ensureVoicePlayer();
      final completer = Completer<bool>();
      late final StreamSubscription<void> sub;
      sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(token == _voiceSessionToken);
        }
      });

      if (player.state == PlayerState.playing) {
        await player.stop();
      }
      if (token != _voiceSessionToken) {
        await sub.cancel();
        return false;
      }

      await player.play(source, volume: 1.0);

      // Guard against dropped completion events by racing with a generous timeout
      // while also polling token cancellation cleanly.
      final cancelTimer = Timer.periodic(
        const Duration(milliseconds: 120),
        (timer) {
          if (token != _voiceSessionToken && !completer.isCompleted) {
            completer.complete(false);
          }
          if (completer.isCompleted) {
            timer.cancel();
          }
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => false,
      );
      cancelTimer.cancel();
      await sub.cancel();
      return result;
    } catch (e) {
      playbackStatus.value = _formatAudioError(e);
      return false;
    }
  }

  @override
  void onClose() {
    unawaited(stopAll());
    unawaited(_voicePlayer?.dispose() ?? Future.value());
    unawaited(_ambiencePlayer?.dispose() ?? Future.value());
    unawaited(_sfxPlayer?.dispose() ?? Future.value());
    super.onClose();
  }
}
