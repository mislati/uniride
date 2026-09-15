import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/ride_matrix_helper.dart'; // Import the new matrix helper
import 'screens/push_notification_service.dart'; // <--- Import the new push service

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Load the Campus Matrix JSON into memory before the app starts
  await RideMatrixHelper.init(); 

  // --- Initialize Push Notifications Safely ---
  try {
    final pushService = PushNotificationService();
    await pushService.initialize();
  } catch (e) {
    debugPrint('Push notifications skipped (likely running on Web): $e');
  }
  // -------------------------------------------
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRide',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6FF), // Soft light background
        primaryColor: const Color(0xFF5A5BFF), // Modern purple/blue
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthScreen(),
    );
  }
}