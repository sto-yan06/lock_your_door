import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';
import '../services/photo_service.dart';
import '../services/logging_service.dart';
import '../widgets/door_targeting_overlay.dart';

class CameraScreen extends StatefulWidget {
  final String itemId;
  final String doorName;

  const CameraScreen({
    Key? key, // FIXED: Use Key? instead of super.key
    required this.itemId,
    required this.doorName,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized || _controller == null) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeCamera();
        break;
      case AppLifecycleState.resumed:
        _initializeCamera();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      LoggingService.info('🔍 DEBUG: Starting camera initialization...');
      
      // Check available cameras
      final cameras = await availableCameras();
      LoggingService.info('🔍 DEBUG: Available cameras: ${cameras.length}');
      
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras available');
        return;
      }

      // Find back camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      LoggingService.info('🔍 DEBUG: Using camera: ${camera.name}');

      // Create controller with proper settings
      _controller = CameraController(
        camera,
        ResolutionPreset.medium, // Lower resolution for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      LoggingService.info('🔍 DEBUG: Initializing camera controller...');
      await _controller!.initialize();
      
      LoggingService.info('🔍 DEBUG: Camera initialized successfully!');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e, st) {
      LoggingService.error('❌ Camera initialization failed', e, st);
      if (mounted) {
        setState(() => _error = 'Camera initialization failed: $e');
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      setState(() => _isInitialized = false);
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      // FIXED: Add small delay to prevent buffer issues
      await Future.delayed(const Duration(milliseconds: 100));
      
      final controller = context.read<LockSessionController>();
      final savedPhotoPath = await PhotoService.captureAndValidateDoorWithTargeting(_controller!);
      
      if (savedPhotoPath != null) {
        // Success with high confidence
        final item = controller.items.firstWhere((item) => item.id == widget.itemId);
        await item.lockWithPhoto(savedPhotoPath);
        controller.notifyListeners();
        
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // ENHANCED: More specific error messages
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('❌ Door not clearly detected'),
                  SizedBox(height: 4),
                  Text(
                    'Tips: Ensure door is well-lit, centered, and fills most of the frame',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      LoggingService.error('Photo capture failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instructions'),
        content: Text(
          '1. Position your device so the ${widget.doorName} fills most of the green frame\n'
          '2. Ensure the door is clearly visible and well-lit\n'
          '3. Avoid having other doors in the background\n'
          '4. Tap the capture button when ready',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
      body: _buildCameraBody(),
    );
  }

  Widget _buildCameraBody() {
    // Show error if there's one
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'Camera Error',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _initializeCamera();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show loading if not initialized
    if (!_isInitialized || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // FIXED: Proper camera preview with aspect ratio
    return Stack(
      children: [
        // Camera preview with proper sizing
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
        // Targeting overlay
        const DoorTargetingOverlay(),
        // Controls at bottom
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: _buildCameraControls(),
        ),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: Icon(Icons.close, color: Colors.white, size: 28),
            iconSize: 32,
          ),
        ),
        // Capture button
        Container(
          decoration: BoxDecoration(
            color: _isCapturing ? Colors.grey : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: IconButton(
            onPressed: _isCapturing ? null : _capturePhoto,
            icon: Icon(
              _isCapturing ? Icons.hourglass_empty : Icons.camera_alt,
              color: Colors.black,
              size: 32,
            ),
            iconSize: 40,
          ),
        ),
        // Instructions button
        Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _showInstructions,
            icon: Icon(Icons.help_outline, color: Colors.white, size: 28),
            iconSize: 32,
          ),
        ),
      ],
    );
  }
}