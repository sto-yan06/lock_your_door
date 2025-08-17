import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'logging_service.dart';

class DoorDetection {
  final String type;
  final double confidence;
  final BoundingBox boundingBox;
  
  DoorDetection({
    required this.type,
    required this.confidence,
    required this.boundingBox,
  });
  
  bool get isDoor => type == 'door';
  bool get isHardware => ['knob', 'lever', 'hinged'].contains(type);
  
  @override
  String toString() => '$type: ${(confidence * 100).toStringAsFixed(1)}%';
}

class BoundingBox {
  final double left, top, width, height;
  
  BoundingBox(this.left, this.top, this.width, this.height);
  
  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  double get area => width * height;
}

class DoorDetectionService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;
  
  // Optimized configuration
  static const int _inputSize = 416;
  static const double _confidenceThreshold = 0.25;
  static const double _nmsThreshold = 0.4;
  
  // Your model classes
  static const List<String> _classes = ['door', 'hinged', 'knob', 'lever'];

  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      LoggingService.info('🤖 Loading TFLite model...');
      
      _interpreter = await Interpreter.fromAsset('assets/models/door_detection.tflite');
      
      // Configure for performance
      _interpreter!.allocateTensors();
      
      final inputShape = _interpreter!.getInputTensor(0).shape;
      LoggingService.info('📊 Model input shape: $inputShape');
      
      _isInitialized = true;
      LoggingService.info('✅ Model ready');
      return true;
    } catch (e) {
      LoggingService.error('Model load failed', e);
      return false;
    }
  }

  /// Fast, simple detection - no ROI complexity
  static Future<List<DoorDetection>> detectDoors(img.Image image) async {
    if (!_isInitialized) return [];

    try {
      final stopwatch = Stopwatch()..start();
      
      // Quick preprocessing
      final input = _prepareInput(image);
      
      // Run inference
      final output = List.filled(1 * 10647 * 9, 0.0).reshape([1, 10647, 9]);
      _interpreter!.run(input, output);
      
      // Simple post-processing
      final detections = _parseDetections(output[0], image.width, image.height);
      
      stopwatch.stop();
      
      if (detections.isNotEmpty) {
        LoggingService.info('🎯 Found ${detections.length} objects in ${stopwatch.elapsedMilliseconds}ms');
      }
      
      return detections;
    } catch (e) {
      LoggingService.error('Detection error', e);
      return [];
    }
  }

  // Legacy method for compatibility
  static Future<List<YoloDetection>> detectObjects(img.Image image) async {
    final detections = await detectDoors(image);
    return detections.map((d) => YoloDetection(
      label: d.type,
      confidence: d.confidence,
      x: d.boundingBox.left,
      y: d.boundingBox.top,
      w: d.boundingBox.width,
      h: d.boundingBox.height,
    )).toList();
  }

  static List<List<List<double>>> _prepareInput(img.Image image) {
    // Efficient resize and normalize
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    
    final input = List.generate(1, (_) => 
      List.generate(_inputSize, (y) => 
        List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }).expand((rgb) => rgb).toList()
      )
    );
    
    return input;
  }

  static List<DoorDetection> _parseDetections(
    List<List<double>> rawOutput,
    int imageWidth,
    int imageHeight,
  ) {
    final candidates = <DoorDetection>[];
    
    for (final detection in rawOutput) {
      if (detection.length < 9) continue;
      
      // Parse YOLO format: [x, y, w, h, objectness, class0, class1, ...]
      final centerX = detection[0];
      final centerY = detection[1];
      final width = detection[2];
      final height = detection[3];
      final objectness = detection[4];
      
      if (objectness < _confidenceThreshold) continue;
      
      // Find best class
      double maxClassScore = 0;
      int bestClass = -1;
      
      for (int i = 0; i < _classes.length; i++) {
        final score = detection[5 + i] * objectness;
        if (score > maxClassScore) {
          maxClassScore = score;
          bestClass = i;
        }
      }
      
      if (bestClass == -1 || maxClassScore < _confidenceThreshold) continue;
      
      // Convert to image coordinates
      final left = (centerX - width / 2) * imageWidth;
      final top = (centerY - height / 2) * imageHeight;
      final w = width * imageWidth;
      final h = height * imageHeight;
      
      candidates.add(DoorDetection(
        type: _classes[bestClass],
        confidence: maxClassScore,
        boundingBox: BoundingBox(left, top, w, h),
      ));
    }
    
    // Simple NMS
    return _applyNMS(candidates);
  }

  static List<DoorDetection> _applyNMS(List<DoorDetection> detections) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    final kept = <DoorDetection>[];
    final suppressed = List<bool>.filled(detections.length, false);
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      kept.add(detections[i]);
      
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        if (_calculateIoU(detections[i].boundingBox, detections[j].boundingBox) > _nmsThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    return kept;
  }

  static double _calculateIoU(BoundingBox a, BoundingBox b) {
    final intersectionLeft = max(a.left, b.left);
    final intersectionTop = max(a.top, b.top);
    final intersectionRight = min(a.right, b.right);
    final intersectionBottom = min(a.bottom, b.bottom);
    
    if (intersectionLeft >= intersectionRight || intersectionTop >= intersectionBottom) {
      return 0.0;
    }
    
    final intersectionArea = (intersectionRight - intersectionLeft) * (intersectionBottom - intersectionTop);
    final unionArea = a.area + b.area - intersectionArea;
    
    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

// Legacy class for compatibility with existing code
class YoloDetection {
  final String label;
  final double confidence;
  final double x, y, w, h;
  
  YoloDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}