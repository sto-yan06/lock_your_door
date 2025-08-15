import 'package:flutter/material.dart';

class DoorTargetingOverlay extends StatelessWidget {
  const DoorTargetingOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: DoorTargetingPainter(),
    );
  }
}

class DoorTargetingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // FIXED: Semi-transparent dark overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final targetPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Calculate target area (centered rectangle for door)
    final targetWidth = size.width * 0.7;
    final targetHeight = size.height * 0.6;
    final targetLeft = (size.width - targetWidth) / 2;
    final targetTop = (size.height - targetHeight) / 2;

    final targetRect = Rect.fromLTWH(targetLeft, targetTop, targetWidth, targetHeight);

    // FIXED: Create a path that covers everything EXCEPT the target area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height)) // Full screen
      ..addRect(targetRect) // Target area
      ..fillType = PathFillType.evenOdd; // This creates the "hole" effect

    // Draw the overlay with the cutout
    canvas.drawPath(path, overlayPaint);

    // Draw the green border around the target area
    canvas.drawRect(targetRect, targetPaint);

    // Draw corner guides for better visibility
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Top-left corner
    canvas.drawLine(
      Offset(targetLeft, targetTop),
      Offset(targetLeft + cornerLength, targetTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(targetLeft, targetTop),
      Offset(targetLeft, targetTop + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(targetLeft + targetWidth, targetTop),
      Offset(targetLeft + targetWidth - cornerLength, targetTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(targetLeft + targetWidth, targetTop),
      Offset(targetLeft + targetWidth, targetTop + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(targetLeft, targetTop + targetHeight),
      Offset(targetLeft + cornerLength, targetTop + targetHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(targetLeft, targetTop + targetHeight),
      Offset(targetLeft, targetTop + targetHeight - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(targetLeft + targetWidth, targetTop + targetHeight),
      Offset(targetLeft + targetWidth - cornerLength, targetTop + targetHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(targetLeft + targetWidth, targetTop + targetHeight),
      Offset(targetLeft + targetWidth, targetTop + targetHeight - cornerLength),
      cornerPaint,
    );

    // Draw instruction text
    final textSpan = TextSpan(
      text: 'Position the door within the frame',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.7),
          ),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        targetTop - 40,
      ),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}