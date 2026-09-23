import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../core/utils/camera_filters.dart';
import 'camera_effects_service.dart';

class MediaDownloaderService {
  static const String albumName = 'HeartPearl';

  /// Save newly captured photo or video to device gallery.
  /// If [filter] or [beauty] was applied to photo, it renders the effects first.
  static Future<bool> saveCapturedMedia({
    required String filePath,
    required bool isVideo,
    BeautyFilter? filter,
    double filterIntensity = 0.65,
    BeautySettings beauty = const BeautySettings(),
  }) async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) return false;
      }

      if (isVideo) {
        await Gal.putVideo(filePath, album: albumName);
        return true;
      }

      // Handle Photo
      File photoFile = File(filePath);
      File? renderedPhoto;
      final activeFilter = filter ?? BeautyFilter.all.first;

      if (!activeFilter.isOriginal || beauty.hasEffect) {
        try {
          renderedPhoto = await CameraEffectsService().renderPhoto(
            source: photoFile,
            filter: activeFilter,
            filterIntensity: filterIntensity,
            beauty: beauty,
          );
          photoFile = renderedPhoto;
        } catch (e) {
          debugPrint('Error rendering photo for save: $e');
        }
      }

      await Gal.putImage(photoFile.path, album: albumName);

      if (renderedPhoto != null && renderedPhoto.path != filePath) {
        try {
          await renderedPhoto.delete();
        } catch (_) {}
      }

      return true;
    } on GalException catch (e) {
      debugPrint('GalException saving captured media: ${e.type.message}');
      return false;
    } catch (e) {
      debugPrint('Error saving captured media: $e');
      return false;
    }
  }

  /// Download a remote photo or video from URL and save it to the device photo library.
  static Future<bool> saveRemoteMedia({
    required String url,
    required bool isVideo,
  }) async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) return false;
      }

      // Download file to temp
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 40),
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        debugPrint('Failed to download media: HTTP ${response.statusCode}');
        return false;
      }

      final ext = isVideo ? 'mp4' : 'jpg';
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/heartpearl_download_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );

      await tempFile.writeAsBytes(response.bodyBytes, flush: true);

      if (isVideo) {
        await Gal.putVideo(tempFile.path, album: albumName);
      } else {
        await Gal.putImage(tempFile.path, album: albumName);
      }

      try {
        await tempFile.delete();
      } catch (_) {}

      return true;
    } on GalException catch (e) {
      debugPrint('GalException saving remote media: ${e.type.message}');
      return false;
    } catch (e) {
      debugPrint('Error saving remote media: $e');
      return false;
    }
  }
}
