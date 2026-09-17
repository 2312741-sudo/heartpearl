import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class MediaHelper {
  /// Fix front-camera selfie mirroring by baking EXIF orientation and horizontally flipping pixels.
  /// Runs on a separate background isolate to keep UI thread silky smooth.
  static Future<String> mirrorFrontCameraPhoto(String filePath) async {
    try {
      return await Isolate.run(() async {
        final file = File(filePath);
        if (!file.existsSync()) return filePath;
        final bytes = await file.readAsBytes();
        final rawImage = img.decodeImage(bytes);
        if (rawImage == null) return filePath;

        // 1. Bake EXIF orientation so portrait/landscape rotation is physically baked into pixel grid
        final oriented = img.bakeOrientation(rawImage);

        // 2. Flip horizontally so the captured photo matches the mirror viewfinder 1:1
        final flipped = img.flipHorizontal(oriented);

        // 3. Encode back as JPEG with high quality (92%)
        final encoded = img.encodeJpg(flipped, quality: 92);
        await file.writeAsBytes(encoded);
        return filePath;
      });
    } catch (e) {
      debugPrint('MediaHelper mirrorFrontCameraPhoto error: $e');
      return filePath;
    }
  }

  /// Optimize and compress photo before uploading to cloud storage.
  /// Reduces size by ~90-95% (e.g. from 8MB to ~200KB) on a background isolate,
  /// preserving crystal-clear Retina display quality while making uploads and downloads up to 20x faster.
  static Future<File> optimizePhotoForUpload(File originalFile) async {
    try {
      final path = originalFile.path;
      final optimizedBytes = await Isolate.run(() async {
        final file = File(path);
        if (!file.existsSync()) return null;
        final bytes = await file.readAsBytes();
        var image = img.decodeImage(bytes);
        if (image == null) return null;

        // 1. Bake orientation
        image = img.bakeOrientation(image);

        // 2. Downscale to max 1440px on longest edge (ideal for 3:4 mobile screen)
        const int maxDimension = 1440;
        if (image.width > maxDimension || image.height > maxDimension) {
          if (image.width > image.height) {
            image = img.copyResize(image, width: maxDimension, interpolation: img.Interpolation.linear);
          } else {
            image = img.copyResize(image, height: maxDimension, interpolation: img.Interpolation.linear);
          }
        }

        // 3. Compress with 85% JPEG quality
        return img.encodeJpg(image, quality: 85);
      });

      if (optimizedBytes != null) {
        final tempDir = originalFile.parent.path;
        final optimizedFile = File('$tempDir/opt_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await optimizedFile.writeAsBytes(optimizedBytes);
        return optimizedFile;
      }
    } catch (e) {
      debugPrint('MediaHelper optimizePhotoForUpload error: $e');
    }
    return originalFile;
  }
}
