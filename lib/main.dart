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
          primary: Color(0xFF4F46E5), // Deep Indigo (Premium look)
          onPrimary: Colors.white,
          secondary: Color(0xFF0EA5E9), // Sky Blue
          onSecondary: Colors.white,
          error: Color(0xFFEF4444),
          onError: Colors.white,
          surface: Color(0xFFF8FAFC), // Slate 50 (Very light gray/blue background)
          onSurface: Color(0xFF0F172A), // Slate 900 (Rich dark text)
          onSurfaceVariant: Color(0xFF64748B), // Slate 500
        ),
        useMaterial3: true,
        // Apply Poppins font globally
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme)
            .apply(
          bodyColor: const Color(0xFF334155), // Slate 700
          displayColor: const Color(0xFF0F172A), 
        ),
        // Card style
        cardTheme: const CardThemeData(
          elevation: 8,
          shadowColor: Color(0x1A000000), // 10% opacity black for softer shadow
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          color: Colors.white,
        ),
        // Input field style
      inputDecorationTheme: InputDecorationTheme(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
            borderSide: BorderSide.none, // No border by default
          ),
          filled: true,
          fillColor: const Color(0xFFF1F5F9), // Slate 100
          labelStyle: const TextStyle(color: Color(0xFF475569)),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIconColor: Color(0xFF64748B),
          suffixIconColor: Color(0xFF64748B),
        ),
        // Elevated Button style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5), 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 4,
            shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Text Button style
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ), // প্রফেশনাল কালার
      home: const SplashScreen(),
    );
  }
}