import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';
import '../services/photo_service.dart';

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
  bool _isCapturing = false;
  bool _isCameraInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras available');
        return;
      }

      // FIXED: Use back camera (index 0) instead of front camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera, // Use back camera for door photos
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final controller = context.read<LockSessionController>();
      
      // Use dual capture method
      final savedPhotoPath = await PhotoService.captureAndValidateDoor(_controller!);
      
      if (savedPhotoPath != null) {
        // Door detected - update the item
        final item = controller.items.firstWhere((item) => item.id == widget.itemId);
        item.isLocked = true;
        item.photoPath = savedPhotoPath;
        item.timestamp = DateTime.now();
        await item.save();
        controller.notifyListeners();
        
        // FIXED: Check mounted before using context
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // Not a door - FIXED: Check mounted before using context
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No door detected. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // FIXED: Check mounted before using context
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // FIXED: Check mounted before calling setState
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Lock ${widget.doorName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),
        
        // Instructions overlay
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Point the camera at ${widget.doorName} and tap the capture button',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        // Capture button
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isCapturing ? null : _capturePhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isCapturing ? Colors.grey : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 4),
                ),
                child: _isCapturing 
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.camera_alt, size: 40),
              ),
            ),
          ),
        ),
        
        // Cancel button
        Positioned(
          bottom: 120,
          left: 40,
          child: IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}