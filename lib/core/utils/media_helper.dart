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
}
