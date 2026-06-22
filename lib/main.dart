import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'splash_screen.dart'; // Corrected import path (Assuming file is now in lib folder)
import 'theme_manager.dart';
import 'language_manager.dart';
import 'local_notification_service.dart';
import 'fcm_service.dart';

// Global key for context-less notifications
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Ensure that Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore offline persistence globally
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize Date formatting locales
  await initializeDateFormatting();

  // Load the stored theme preference before running the app
  await ThemeManager().loadTheme();
  // Initialize Language Manager
  await LanguageManager().init();
  
  // Initialize Local Notifications
  await LocalNotificationService.init();

  // Initialize FCM (Web/Mobile Push)
  await FcmService.init();

  runApp(const StudyMateApp());
}

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeManager(), LanguageManager()]),
      builder: (context, _) {
        return MaterialApp(
          title: 'StudyMate',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: ThemeManager().currentThemeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}