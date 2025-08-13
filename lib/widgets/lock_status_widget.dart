import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';
import 'dart:io';

class LockStatusWidget extends StatelessWidget {
  const LockStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LockSessionController>(
      builder: (context, controller, child) {
        // Get summary of all items
        final totalItems = controller.items.length;
        final lockedItems = controller.items.where((item) => item.isLocked).length;
        final hasAnyPhoto = controller.items.any((item) => item.photoPath != null);
        final latestItem = controller.items.isNotEmpty 
            ? controller.items.reduce((a, b) => 
                (a.timestamp?.isAfter(b.timestamp ?? DateTime(1970)) ?? false) ? a : b)
            : null;

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
                    "Lock Status",
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
                      color: lockedItems == totalItems && totalItems > 0 
                          ? Colors.green 
                          : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                totalItems == 0 
                    ? "No items added"
                    : "$lockedItems of $totalItems items locked",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (latestItem?.timestamp != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Last update: ${_formatTimestamp(latestItem!.timestamp!)}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
              if (hasAnyPhoto) _buildLastPhoto(latestItem?.photoPath),
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
    
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_not_supported,
                color: Colors.white54,
                size: 40,
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return "${diff.inDays}d ago";
    } else if (diff.inHours > 0) {
      return "${diff.inHours}h ago";
    } else if (diff.inMinutes > 0) {
      return "${diff.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }
}