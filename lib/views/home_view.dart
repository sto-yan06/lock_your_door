import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';
import 'dart:io';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<bool?> _showUnlockConfirmation(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlock $name?'),
        content: const Text('Are you sure you want to unlock this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, String photoPath, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: Image.file(File(photoPath), fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context, LockSessionController controller) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Item'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Back Door, Garage, Safe',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final value = textController.text.trim();
                if (value.isNotEmpty) Navigator.pop(ctx, value);
              },
              child: const Text('Add'),
            ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      controller.addItem(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LockSessionController>();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Custom header (instead of default app bar look)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: const [
                Text(
                  'Room 1 ▾',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ...controller.items.map(
                  (item) => _DeviceCard(
                    item: item,
                    onViewPhoto: item.photoPath != null
                        ? () => _showPhotoDialog(
                              context,
                              item.photoPath!,
                              item.name,
                            )
                        : null,
                    onToggle: () async {
                      if (item.isLocked) {
                        final confirm =
                            await _showUnlockConfirmation(context, item.name);
                        if (confirm == true) {
                          await controller.unlockItem(item.id);
                        }
                      } else {
                        // Updated lock flow with error handling
                        final error = await controller.lockItem(item.id);
                        if (error != null &&
                            error != "Photo cancelled." &&
                            context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _AddItemButton(
                  onTap: () => _showAddItemDialog(context, controller),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final LockItem item;
  final VoidCallback onToggle;
  final VoidCallback? onViewPhoto;

  const _DeviceCard({
    required this.item,
    required this.onToggle,
    this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E88FF), width: 2),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .08),
            Colors.white.withValues(alpha: .04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onViewPhoto,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: item.isLocked ? Colors.greenAccent : Colors.redAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (item.timestamp != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            _fmtTs(item.timestamp!),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.photoPath != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Tap to view photo',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: item.isLocked ? Colors.orange : Colors.green,
                  minimumSize: const Size(90, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  item.isLocked ? 'Unlock' : 'Lock',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTs(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AddItemButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddItemButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: const [
            Expanded(
              child: Text(
                'Add Item',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Icon(Icons.add, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}