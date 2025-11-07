// services/video_cache_service.dart
import 'dart:io';
import 'dart:developer' as developer;
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  static const String _videoBoxName = 'video_cache';
  late Box<String> _videoBox;
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _videoBox = await Hive.openBox<String>(_videoBoxName);
      developer.log("VideoCacheService initialized successfully");
    } catch (e) {
      developer.log("Error initializing VideoCacheService: $e");
    }
  }

  Future<String?> getCachedVideoPath(int danceId) async {
    try {
      final String? cachedPath = _videoBox.get(danceId.toString());
      if (cachedPath != null && await File(cachedPath).exists()) {
        developer.log("Found cached video for dance $danceId at: $cachedPath");
        return cachedPath;
      }
      return null;
    } catch (e) {
      developer.log("Error getting cached video: $e");
      return null;
    }
  }

  Future<void> cacheVideo(int danceId, String videoUrl) async {
    try {
      developer.log("Caching video for dance $danceId from: $videoUrl");

      final file = await _cacheManager.getSingleFile(videoUrl);
      if (await file.exists()) {
        await _videoBox.put(danceId.toString(), file.path);
        developer.log("Video cached successfully for dance $danceId at: ${file.path}");
      }
    } catch (e) {
      developer.log("Error caching video: $e");
    }
  }

  Future<bool> isVideoCached(int danceId) async {
    try {
      final String? cachedPath = _videoBox.get(danceId.toString());
      if (cachedPath != null) {
        return await File(cachedPath).exists();
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearCache() async {
    try {
      await _videoBox.clear();
      await _cacheManager.emptyCache();
      developer.log("Video cache cleared successfully");
    } catch (e) {
      developer.log("Error clearing cache: $e");
    }
  }

  Future<int> getCacheSize() async {
    try {
      int totalSize = 0;
      for (var key in _videoBox.keys) {
        final path = _videoBox.get(key);
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            totalSize += await file.length();
          }
        }
      }
      return totalSize;
    } catch (e) {
      developer.log("Error getting cache size: $e");
      return 0;
    }
  }

  // Optional: Pre-cache videos on app start
  Future<void> preCacheVideos(Map<int, String> videoUrls) async {
    try {
      for (final entry in videoUrls.entries) {
        final danceId = entry.key;
        final videoUrl = entry.value;

        if (!await isVideoCached(danceId)) {
          developer.log("Pre-caching video for dance $danceId");
          await cacheVideo(danceId, videoUrl);
        }
      }
    } catch (e) {
      developer.log("Error pre-caching videos: $e");
    }
  }
}