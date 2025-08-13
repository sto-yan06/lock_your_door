import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'controllers/lock_session_controller.dart';
import 'models/lock_item.dart';
import 'ui/launch_screen.dart';
import 'services/door_detection_service.dart';

void main() async {
  // Ensure Flutter is ready.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AI model for door detection
  await DoorDetectionService.loadModel();
  await DoorDetectionService.warmup(); // preload TFLite

  // Initialize Hive and specify a subdirectory for its files.
  await Hive.initFlutter();

  // --- 1. Securely manage the encryption key ---
  const secureStorage = FlutterSecureStorage();
  // The key used to store the encryption key in secure storage
  const hiveEncryptionKey = 'hive_encryption_key';
  
  String? base64Key = await secureStorage.read(key: hiveEncryptionKey);
  
  // If no key is found, generate one and save it
  if (base64Key == null) {
    final key = Hive.generateSecureKey();
    base64Key = base64Encode(key);
    await secureStorage.write(key: hiveEncryptionKey, value: base64Key);
  }
  
  final encryptionKey = base64Decode(base64Key);

  // --- 2. Register adapter and open the ENCRYPTED box ---
  Hive.registerAdapter(LockItemAdapter());

  await Hive.openBox<LockItem>(
    'lock_items',
    // Pass the encryption key to Hive
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  // --- The rest of your initialization logic is the same ---
  final lockSessionController = LockSessionController();
  await lockSessionController.loadInitialData();

  runApp(
    ChangeNotifierProvider.value(
      value: lockSessionController,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lock Your Door',
      theme: ThemeData(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const LaunchScreen(),
    );
  }
}
