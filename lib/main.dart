import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'splash_screen.dart'; // Corrected import path (Assuming file is now in lib folder)
import 'theme_manager.dart';
import 'language_manager.dart';

void main() async {
  // Ensure that Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp();
  // Initialize date formatting locales
  await initializeDateFormatting();

  // Load the stored theme preference before running the app
  await ThemeManager().loadTheme();
  // Initialize Language Manager
  await LanguageManager().init();

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
          theme: ThemeManager().currentThemeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}