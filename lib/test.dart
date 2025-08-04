import 'package:flutter/material.dart';
import 'dart:io';
import '../services/photo_service.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String? _savedImagePath;

  void _handleTakePhoto() async {
    final path = await PhotoService.takeAndSavePhotoWithTimestamp();
    if (path != null) {
      setState(() {
        _savedImagePath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Poza + Timestamp")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _handleTakePhoto,
              child: const Text("Fă Poză"),
            ),
            const SizedBox(height: 20),
            if (_savedImagePath != null)
              Image.file(File(_savedImagePath!)),
          ],
        ),
      ),
    );
  }
}