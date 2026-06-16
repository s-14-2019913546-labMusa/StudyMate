import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'splash_screen.dart'; // Corrected import path (Assuming file is now in lib folder)

void main() async {
  // Ensure that Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const StudyMateApp());
}

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Define your custom color scheme
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF0052CC), // Royal Blue
          onPrimary: Colors.white,
          secondary: Color(0xFF0052CC), // Can be same as primary or a complementary color
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: Color(0xFFF5F5F5), // Replacement for background
          onSurface: Color(0xFF121212), // Replacement for onBackground
          onSurfaceVariant: Color(0xFF616161), // Lighter gray for secondary text
        ),
        useMaterial3: true,
        // Apply Poppins font globally
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme)
            .apply(
          bodyColor: const Color(0xFF333333), // Dark Gray
          displayColor: const Color(0xFF121212), // Deep Black
        ),
        // Card style
        cardTheme: const CardThemeData(
          elevation: 4,
          shadowColor: Color(0x14000000), // 8% opacity black
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          color: Colors.white,
        ),
        // Input field style
      inputDecorationTheme: InputDecorationTheme(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide.none, // No border by default
          ),
          filled: true,
          fillColor: const Color(0xFFEEEEEE), 
          labelStyle: const TextStyle(color: Color(0xFF333333)),
          hintStyle: const TextStyle(color: Color(0xFF616161)),
          prefixIconColor: const Color(0xFF616161),
          suffixIconColor: const Color(0xFF616161),
        ),
        // Elevated Button style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0052CC), // Royal Blue
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Text Button style
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0052CC), // Royal Blue
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ), // প্রফেশনাল কালার
      home: const SplashScreen(),
    );
  }
}