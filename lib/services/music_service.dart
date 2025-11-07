// music_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _shouldPlayOnResume = false;
  String _currentScreen = '';

  Future<void> initialize() async {
    await _player.setReleaseMode(ReleaseMode.loop);

    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });
  }

  Future<void> playMenuMusic({String screenName = 'menu'}) async {
    if (_isMuted) return;

    try {
      // Only play if we're not already playing or if screen changed
      if (!_isPlaying || _currentScreen != screenName) {
        await _player.play(AssetSource('audio/background_music.mp3'));
        _isPlaying = true;
        _shouldPlayOnResume = true;
        _currentScreen = screenName;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing music: $e');
      }
    }
  }

// In music_service.dart
  Future<void> playGameMusic({required int danceId}) async {
    if (_isMuted) return;

    if (kDebugMode) {
      print('Attempting to play music for dance ID: $danceId');
    }

    try {
      await _player.stop();

      String audioFile;
      if (danceId == 1) {
        audioFile = 'audio/jumbo1.mp3';
      } else if (danceId == 2) {
        audioFile = 'audio/modelo.mp3';
      } else if (danceId == 99) {
        audioFile = 'audio/funk.mp3';
      }else if (danceId == 3) {
        audioFile = 'audio/salt.mp3';
      }else if (danceId == 4) {
        audioFile = 'audio/burning.mp3';
      } else {
        audioFile = 'audio/background_music.mp3';
      }

      if (kDebugMode) {
        print('Playing audio file: $audioFile');
      }

      await _player.play(AssetSource(audioFile));
      _isPlaying = true;
      _shouldPlayOnResume = false;
      _currentScreen = 'gameplay';

      if (kDebugMode) {
        print('Music started successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing game music: $e');
      }
      await playMenuMusic(screenName: 'gameplay');
    }
  }

  Future<void> stopMusic() async {
    await _player.stop();
    _isPlaying = false;
    _shouldPlayOnResume = false;
    _currentScreen = '';
  }

  Future<void> pauseMusic({bool rememberToResume = true}) async {
    _shouldPlayOnResume = rememberToResume && _isPlaying;
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resumeMusic({String screenName = ''}) async {
    if (_isMuted || !_shouldPlayOnResume) return;

    try {
      if (screenName.isNotEmpty) {
        _currentScreen = screenName;
      }

      await _player.resume();
      _isPlaying = true;
    } catch (e) {
      // If resume fails, try playing from the beginning
      if (_shouldPlayOnResume) {
        await playMenuMusic(screenName: screenName);
      }
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      pauseMusic(rememberToResume: false);
    } else if (_shouldPlayOnResume) {
      resumeMusic();
    }
  }

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  String get currentScreen => _currentScreen;

  void dispose() {
    _player.dispose();
  }
}