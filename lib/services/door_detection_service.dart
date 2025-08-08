import 'dart:io';
import 'package:image/image.dart' as img;
import 'logging_service.dart';

/// A simple heuristic-based service to detect if an image likely contains a door.
class DoorDetectionService {
  // --- These values can be tuned for better accuracy ---
  static const double minAspect = 1.5; // Doors are taller than they are wide
  static const double maxAspect = 3.5;
  static const double minVerticalEdgeRatio = 0.01; // % of pixels that are strong vertical edges
  static const double minSideConcentration = 0.30; // % of edge energy in the left/right thirds
  static const double minLuma = 20; // Avoid pure black images
  static const int downscaleWidth = 100; // Process a smaller image for speed

  /// Analyzes the image at the given path and returns true if it's likely a door.
  static Future<bool> isDoor(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;

      // 1. Aspect Ratio check: Is the image portrait-oriented like a door?
      final aspect = image.height / image.width;
      if (aspect < minAspect || aspect > maxAspect) {
        LoggingService.debug('Door check failed: Invalid aspect ratio ($aspect)');
        return false;
      }

      // Downscale for performance
      final smallImage = img.copyResize(image, width: downscaleWidth);
      final w = smallImage.width;
      final h = smallImage.height;

      // 2. Vertical Edge Detection (using Sobel filter)
      final sobel = img.sobel(smallImage);
      int strongVerticalEdges = 0;
      double sideEdgeEnergy = 0;
      double totalEdgeEnergy = 0;
      double lumaSum = 0;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final edgePixel = sobel.getPixel(x, y);
          final edgeMagnitude = img.getLuminance(edgePixel);
          totalEdgeEnergy += edgeMagnitude;

          // Count strong edges, especially on the sides (door frame)
          if (edgeMagnitude > 150) {
            strongVerticalEdges++;
            if (x < w / 3.5 || x > w - (w / 3.5)) {
              sideEdgeEnergy += edgeMagnitude;
            }
          }
          lumaSum += img.getLuminance(smallImage.getPixel(x, y));
        }
      }

      // 3. Check if there are enough vertical edges
      final verticalEdgeRatio = strongVerticalEdges / (w * h);
      if (verticalEdgeRatio < minVerticalEdgeRatio) {
        LoggingService.debug('Door check failed: Not enough vertical edges ($verticalEdgeRatio)');
        return false;
      }

      // 4. Check if edges are concentrated on the sides
      final edgeSideConcentration = totalEdgeEnergy > 0 ? sideEdgeEnergy / totalEdgeEnergy : 0;
      if (edgeSideConcentration < minSideConcentration) {
        LoggingService.debug('Door check failed: Edge concentration too low ($edgeSideConcentration)');
        return false;
      }

      // 5. Check if the image is not too dark
      final avgLuma = lumaSum / (w * h);
      if (avgLuma < minLuma) {
        LoggingService.debug('Door check failed: Image too dark ($avgLuma)');
        return false;
      }

      // If all checks pass, it's probably a door.
      LoggingService.info('Door detection successful for $path');
      return true;
    } catch (e, s) {
      LoggingService.error('Error during door detection', e, s);
      // If any error occurs during processing, assume it's not a valid door image.
      return false;
    }
  }
}