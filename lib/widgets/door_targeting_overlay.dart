import 'package:flutter/material.dart';

class DoorTargetingOverlay extends StatelessWidget {
  const DoorTargetingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: const Center(
        child: Text(
          'Point camera at door',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}