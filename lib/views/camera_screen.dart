import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../controllers/lock_session_controller.dart';
import '../services/door_detection_service.dart';
import '../services/logging_service.dart';

class CameraScreen extends StatefulWidget {
  final String itemId;
  final String doorName;

  const CameraScreen({
    super.key,
    required this.itemId,
    required this.doorName,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _error;
  
  // Detection state
  String _status = "Point camera at door";
  Color _statusColor = Colors.orange;
  List<DoorDetection> _lastDetections = [];
  
  // Performance optimization
  Timer? _detectionTimer;
  bool _isProcessing = false;
  static const Duration _detectionInterval = Duration(milliseconds: 1000); // Reduced frequency

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras available');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium, // Balanced quality/performance
        enableAudio: false,
      );

      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
        _startDetection();
      }
    } catch (e) {
      LoggingService.error('Camera init failed', e);
      if (mounted) {
        setState(() => _error = 'Camera error: $e');
      }
    }
  }

  void _startDetection() {
    _detectionTimer = Timer.periodic(_detectionInterval, (_) {
      if (!_isProcessing && _controller?.value.isInitialized == true) {
        _runDetection();
      }
    });
  }

  Future<void> _runDetection() async {
    if (_isProcessing || _isCapturing) return;
    
    _isProcessing = true;
    
    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      
      if (decodedImage != null) {
        final detections = await DoorDetectionService.detectDoors(decodedImage);
        
        if (mounted) {
          setState(() {
            _lastDetections = detections;
            _updateStatus(detections);
          });
          
          // Auto-capture logic
          if (_shouldAutoCapture(detections)) {
            await _capturePhoto(decodedImage);
          }
        }
      }
      
      // Cleanup
      await File(image.path).delete();
    } catch (e) {
      LoggingService.error('Detection failed', e);
    } finally {
      _isProcessing = false;
    }
  }

  void _updateStatus(List<DoorDetection> detections) {
    final doors = detections.where((d) => d.isDoor).toList();
    final hardware = detections.where((d) => d.isHardware).toList();
    
    if (doors.isEmpty) {
      _status = "Point camera at door";
      _statusColor = Colors.orange;
    } else {
      final bestDoor = doors.first;
      if (bestDoor.confidence > 0.7) {
        if (hardware.isNotEmpty) {
          _status = "Perfect! Door detected with ${hardware.first.type}";
          _statusColor = Colors.green;
        } else {
          _status = "Good door detection";
          _statusColor = Colors.lightGreen;
        }
      } else {
        _status = "Weak door signal - adjust angle";
        _statusColor = Colors.yellow;
      }
    }
  }

  bool _shouldAutoCapture(List<DoorDetection> detections) {
    final doors = detections.where((d) => d.isDoor).toList();
    if (doors.isEmpty) return false;
    
    final bestDoor = doors.first;
    
    // Simple criteria: good confidence and reasonable size
    return bestDoor.confidence > 0.6 && 
           bestDoor.boundingBox.area > 50000; // Minimum door size
  }

  Future<void> _capturePhoto(img.Image doorImage) async {
    if (_isCapturing) return;
    
    setState(() {
      _isCapturing = true;
      _status = "Capturing...";
      _statusColor = Colors.blue;
    });
    
    try {
      await _saveDoorPhoto(doorImage);
      
      if (mounted) {
        // Success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Door photo captured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      LoggingService.error('Capture failed', e);
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _status = "Capture failed - try again";
          _statusColor = Colors.red;
        });
      }
    }
  }

  Future<void> _saveDoorPhoto(img.Image doorImage) async {
    final controller = context.read<LockSessionController>();
    
    // Create directory
    final directory = Directory('/storage/emulated/0/Pictures/LockYourDoor');
    await directory.create(recursive: true);
    
    // Save image
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'door_locked_$timestamp.jpg';
    final file = File('${directory.path}/$filename');
    
    final jpegBytes = img.encodeJpg(doorImage, quality: 85);
    await file.writeAsBytes(jpegBytes);
    
    // Update lock item
    final item = controller.items.firstWhere((item) => item.id == widget.itemId);
    await item.lockWithPhoto(file.path);
    
    LoggingService.info('✅ Photo saved: ${file.path}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Lock ${widget.doorName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorWidget();
    }
    
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera preview - full screen
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize?.height ?? 1,
              height: _controller!.value.previewSize?.width ?? 1,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        
        // Simple detection overlay
        if (_lastDetections.isNotEmpty) _buildDetectionOverlay(),
        
        // Status bar
        Positioned(
          top: 20,
          left: 16,
          right: 16,
          child: _buildStatusBar(),
        ),
        
        // Controls
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: _buildControls(),
        ),
      ],
    );
  }

  Widget _buildDetectionOverlay() {
    return CustomPaint(
      painter: DetectionPainter(_lastDetections, _controller!.value.previewSize!),
      child: Container(),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Door Detection',
            style: TextStyle(
              color: _statusColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _status,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel
        Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _isCapturing ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ),
        
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            _isCapturing ? 'CAPTURING...' : 'SCANNING...',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Manual capture
        Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _isCapturing ? null : () async {
              if (_controller?.value.isInitialized == true) {
                final image = await _controller!.takePicture();
                final bytes = await image.readAsBytes();
                final decodedImage = img.decodeImage(bytes);
                if (decodedImage != null) {
                  await _capturePhoto(decodedImage);
                }
                await File(image.path).delete();
              }
            },
            icon: const Icon(Icons.camera, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Camera Error',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() => _error = null);
              _initializeCamera();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<DoorDetection> detections;
  final Size previewSize;
  
  DetectionPainter(this.detections, this.previewSize);
  
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / previewSize.width;
    final scaleY = size.height / previewSize.height;
    
    for (final detection in detections) {
      final rect = Rect.fromLTWH(
        detection.boundingBox.left * scaleX,
        detection.boundingBox.top * scaleY,
        detection.boundingBox.width * scaleX,
        detection.boundingBox.height * scaleY,
      );
      
      final paint = Paint()
        ..color = detection.isDoor ? Colors.green : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawRect(rect, paint);
      
      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection.type} ${(detection.confidence * 100).toInt()}%',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
