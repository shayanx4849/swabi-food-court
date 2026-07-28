import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Launch the UI immediately — don't block app startup on notification
  // setup/permission dialogs. If this were awaited here, a stuck or slow
  // permission prompt would freeze the entire app before anything renders.
  runApp(const BachaoKhanaApp());
  NotificationService.init();
}

class BachaoKhanaApp extends StatelessWidget {
  const BachaoKhanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: false,
      ),
      home: const SplashScreen(),
    );
  }
}
