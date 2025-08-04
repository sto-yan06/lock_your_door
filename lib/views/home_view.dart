import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';
import 'dart:io';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<bool?> _showUnlockConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Unlock!'),
        content: const Text('Are you sure you want to unlock the door?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, String photoPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Last Photo'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LockSessionController>(
      builder: (context, controller, child) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF663399),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: controller.lastPhotoPath != null 
                    ? () => _showPhotoDialog(context, controller.lastPhotoPath!)
                    : null,
                  borderRadius: BorderRadius.circular(25),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Door 1",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  "Status: ",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: controller.isLocked 
                                      ? Colors.green 
                                      : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (controller.lastPhotoPath != null)
                              const Text(
                                "Tap to view photo",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ElevatedButton(
                              onPressed: () async {
                                if (controller.isLocked) {
                                  final confirm = await _showUnlockConfirmation(context);
                                  if (confirm == true) {
                                    await controller.unlock();
                                  }
                                } else {
                                  await controller.startLockSession();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: controller.isLocked 
                                  ? Colors.orange 
                                  : Colors.green,
                                minimumSize: const Size(100, 36),
                              ),
                              child: Text(
                                controller.isLocked ? "Unlock" : "Lock",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}