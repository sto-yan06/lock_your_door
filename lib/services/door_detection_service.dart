import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'logging_service.dart';

/// Represents a single detected object.
class YoloDetection {
  final String label;
  final double confidence;
  final double x, y, w, h; // Bounding box in original image coordinates

  YoloDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  @override
  String toString() {
    return 'Detection(label: $label, conf: ${confidence.toStringAsFixed(3)}, box: [${x.round()}, ${y.round()}, ${w.round()}, ${h.round()}])';
  }
}

/// Helper class for letterboxing result. MUST be a top-level class.
class _LetterboxResult {
  final img.Image image;
  final double scale;
  final double padX, padY;
  _LetterboxResult(this.image, this.scale, this.padX, this.padY);
}

class DoorDetectionService {
  static const int _modelInputSize = 640;
  static const double _confidenceThreshold = 0.30;
  static const double _iouThreshold = 0.45;

  static Interpreter? _interpreter;
  static List<String>? _labels;

  static bool get isLoaded => _interpreter != null;

  /// For backward compatibility with existing code
  static Future<void> load() => loadModel();
  
  /// Preload model and run a single inference with empty data
  static Future<void> warmup() async {
    if (!isLoaded) await loadModel();
    try {
      // Create a dummy image for warmup
      final dummyImage = img.Image(width: _modelInputSize, height: _modelInputSize);
      img.fill(dummyImage, color: img.ColorRgb8(114, 114, 114));
      
      // Run detection on the dummy image
      await detectObjects(dummyImage);
      LoggingService.info('✅ Model warmup completed successfully');
    } catch (e) {
      LoggingService.error('❌ Model warmup failed', e);
    }
  }

  /// Loads the TFLite model and labels from assets. Call this at app startup.
  static Future<void> loadModel() async {
    if (isLoaded) return;
    try {
      // Load labels
      final labelsRaw = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsRaw
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Load model (path must match pubspec assets entry)
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float16.tflite',
        options: InterpreterOptions()..threads = 2,
      );

      final out0 = _interpreter!.getOutputTensor(0);
      LoggingService.info(
        '✅ YOLOv8 Model Loaded. '
        'Output #0 name=${out0.name}, dtype=${out0.type}, shape=${out0.shape}, '
        'Labels(${_labels!.length}): $_labels',
      );
    } catch (e, st) {
      LoggingService.error('❌ Failed to load model.', e, st);
      _interpreter = null;
    }
  }

  /// Main public method to check if an image contains a door.
  static Future<bool> isDoorImage(img.Image originalImage, {double doorConfidence = 0.5}) async {
    final detections = await detectObjects(originalImage);
    if (detections.isEmpty) {
      LoggingService.info("No objects detected.");
      return false;
    }
    final bool foundDoor = detections.any((d) => d.label == 'door' && d.confidence >= doorConfidence);
    LoggingService.info("Door validation result: $foundDoor");
    return foundDoor;
  }

  /// Runs object detection on an image and returns a list of detected objects.
  static Future<List<YoloDetection>> detectObjects(img.Image originalImage) async {
    if (!isLoaded || _labels == null) {
      LoggingService.error("Model not loaded, cannot run detection.");
      return [];
    }

    // 1) Preprocess (letterbox to 640x640)
    final letterboxResult = _letterbox(originalImage);

    // 2) Build input [1, 640, 640, 3] as nested List (float32)
    final input = _prepareInput4D(letterboxResult.image);

    // 3) Prepare output buffer according to actual model output shape
    final outTensor = _interpreter!.getOutputTensor(0);
    final outShape = List<int>.from(outTensor.shape); // e.g., [1, 84, 8400] or [1, 8400, 84]
    final output = _allocNestedFloatList(outShape);

    // 4) Inference
    try {
      _interpreter!.runForMultipleInputs([input], {0: output});
    } catch (e, st) {
      LoggingService.error("❌ Model inference failed.", e, st);
      return [];
    }

    // 5) Post-process
    final rawDetections = _parseOutputNested(output, outShape);
    final scaledDetections = _scaleBoxes(rawDetections, letterboxResult, originalImage.width, originalImage.height);
    final finalDetections = _nonMaxSuppression(scaledDetections);

    LoggingService.info("Final detections after NMS: ${finalDetections.length}");
    for (var det in finalDetections) {
      LoggingService.debug(det.toString());
    }
    return finalDetections;
  }

  /// FIXED: Resizes and pads the image using Image 4.0 API
  static _LetterboxResult _letterbox(img.Image image) {
    final imageWidth = image.width;
    final imageHeight = image.height;
    final scale = min(_modelInputSize / imageWidth, _modelInputSize / imageHeight);
    final newWidth = (imageWidth * scale).round();
    final newHeight = (imageHeight * scale).round();

    // Resize the image
    final resizedImage = img.copyResize(image, width: newWidth, height: newHeight);

    final padX = (_modelInputSize - newWidth) / 2.0;
    final padY = (_modelInputSize - newHeight) / 2.0;

    // FIXED: Use Image 4.0 API for creating and compositing images
    final letterboxedImage = img.Image(width: _modelInputSize, height: _modelInputSize);
    img.fill(letterboxedImage, color: img.ColorRgb8(114, 114, 114)); // grey pad
    
    // FIXED: Use compositeImage instead of copyInto
    img.compositeImage(letterboxedImage, resizedImage, dstX: padX.round(), dstY: padY.round());

    return _LetterboxResult(letterboxedImage, scale, padX, padY);
  }

  /// Builds a 4-D Float32 (as nested List<double>) with shape [1, 640, 640, 3].
  static List<dynamic> _prepareInput4D(img.Image image) {
    final h = _modelInputSize;
    final w = _modelInputSize;

    // [1, H, W, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        h,
        (_) => List.generate(
          w,
          (_) => List<double>.filled(3, 0.0, growable: false),
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = image.getPixel(x, y); // image v4 returns a Pixel with r/g/b getters
        input[0][y][x][0] = p.r / 255.0;
        input[0][y][x][1] = p.g / 255.0;
        input[0][y][x][2] = p.b / 255.0;
      }
    }
    return input;
  }

  /// Allocates a nested List<double> structure that matches a given shape.
  /// Works for shapes of rank 1..4 (typical for TFLite outputs).
  static dynamic _allocNestedFloatList(List<int> shape) {
    if (shape.isEmpty) return 0.0;
    dynamic build(List<int> dims, int idx) {
      if (idx == dims.length - 1) {
        return List<double>.filled(dims[idx], 0.0, growable: false);
      }
      return List.generate(dims[idx], (_) => build(dims, idx + 1), growable: false);
    }
    return build(shape, 0);
  }

  /// Parses nested output into detections. Supports [1, C, N] or [1, N, C].
  /// Assumes channels = 4 (box) + numClasses.
  static List<YoloDetection> _parseOutputNested(dynamic nested, List<int> shape) {
    if (_labels == null || _labels!.isEmpty) return [];

    // Normalize to [1, channels, numPredictions]
    final bool channelsFirst = (shape.length == 3 && shape[1] < shape[2]); // [1, C, N] means C < N typically
    final int batch = shape[0];
    if (batch != 1) {
      LoggingService.warning('Unexpected batch size: $batch. Proceeding with first batch only.'); // FIXED: warning instead of warn
    }

    final int numClasses = _labels!.length;
    final int channels = 4 + numClasses;

    late int C, N;
    if (channelsFirst) {
      C = shape[1];
      N = shape[2];
    } else {
      N = shape[1];
      C = shape[2];
    }

    if (C != channels) {
      LoggingService.warning('Channel count ($C) != expected (4 + $numClasses = $channels). Proceeding anyway.'); // FIXED: warning instead of warn
    }

    final List<YoloDetection> detections = [];

    for (int i = 0; i < N; i++) {
      // Read box + class scores for prediction i
      double cx, cy, w, h;
      List<double> classScores = List<double>.filled(numClasses, 0.0);

      if (channelsFirst) {
        cx = (nested[0][0][i] as double);
        cy = (nested[0][1][i] as double);
        w  = (nested[0][2][i] as double);
        h  = (nested[0][3][i] as double);
        for (int c = 0; c < numClasses; c++) {
          classScores[c] = (nested[0][4 + c][i] as double);
        }
      } else {
        cx = (nested[0][i][0] as double);
        cy = (nested[0][i][1] as double);
        w  = (nested[0][i][2] as double);
        h  = (nested[0][i][3] as double);
        for (int c = 0; c < numClasses; c++) {
          classScores[c] = (nested[0][i][4 + c] as double);
        }
      }

      // Pick best class
      double bestConf = -1.0;
      int bestIdx = -1;
      for (int c = 0; c < numClasses; c++) {
        final v = classScores[c];
        if (v > bestConf) {
          bestConf = v;
          bestIdx = c;
        }
      }

      if (bestIdx >= 0 && bestConf >= _confidenceThreshold) {
        detections.add(
          YoloDetection(
            label: _labels![bestIdx],
            confidence: bestConf,
            x: cx,
            y: cy,
            w: w,
            h: h,
          ),
        );
      }
    }

    return detections;
  }

  /// Scales bounding boxes from model space (640x640) back to original image space.
  static List<YoloDetection> _scaleBoxes(List<YoloDetection> detections, _LetterboxResult lb, int originalW, int originalH) {
    return detections.map((det) {
      // Undo letterbox padding and scaling
      final double scaledX = (det.x - lb.padX) / lb.scale;
      final double scaledY = (det.y - lb.padY) / lb.scale;
      final double scaledW = det.w / lb.scale;
      final double scaledH = det.h / lb.scale;

      // Convert center (cx, cy, w, h) -> top-left (x, y, w, h)
      final double x1 = scaledX - scaledW / 2.0;
      final double y1 = scaledY - scaledH / 2.0;

      // Clip to image bounds
      final double x = x1.clamp(0.0, originalW.toDouble());
      final double y = y1.clamp(0.0, originalH.toDouble());
      final double w = max(0.0, min(scaledW, originalW.toDouble() - x));
      final double h = max(0.0, min(scaledH, originalH.toDouble() - y));

      return YoloDetection(
        label: det.label,
        confidence: det.confidence,
        x: x, y: y, w: w, h: h,
      );
    }).toList();
  }

  /// Filters out overlapping bounding boxes for the same object class.
  static List<YoloDetection> _nonMaxSuppression(List<YoloDetection> detections) {
    final list = List<YoloDetection>.from(detections);
    list.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<YoloDetection> keep = [];

    for (final d in list) {
      bool ok = true;
      for (final k in keep) {
        if (d.label == k.label && _iou(d, k) > _iouThreshold) {
          ok = false;
          break;
        }
      }
      if (ok) keep.add(d);
    }
    return keep;
  }

  /// Calculates the Intersection over Union (IoU) of two bounding boxes.
  static double _iou(YoloDetection a, YoloDetection b) {
    final double xA = max(a.x, b.x);
    final double yA = max(a.y, b.y);
    final double xB = min(a.x + a.w, b.x + b.w);
    final double yB = min(a.y + a.h, b.y + b.h);

    final double inter = max(0.0, xB - xA) * max(0.0, yB - yA);
    final double areaA = max(0.0, a.w) * max(0.0, a.h);
    final double areaB = max(0.0, b.w) * max(0.0, b.h);
    final double denom = areaA + areaB - inter + 1e-6;
    return denom <= 0 ? 0.0 : (inter / denom);
  }
}