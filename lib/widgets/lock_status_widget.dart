import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';
import '../services/photo_service.dart';
import 'dart:typed_data';

class LockStatusWidget extends StatelessWidget {
  const LockStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LockSessionController>(
      builder: (context, controller, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF663399),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Door Status",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: controller.isLocked ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                controller.isLocked ? "Locked" : "Unlocked",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (controller.lastTimestamp != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Last update: ${controller.lastTimestamp.toString().substring(0, 16)}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
              _buildLastPhoto(controller.lastPhotoPath),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLastPhoto(String? path) {
    if (path == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Uint8List?>(
      future: PhotoService.loadDecryptedImageBytes(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 120,
            height: 120,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            snapshot.data!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}