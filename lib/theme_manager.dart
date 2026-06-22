import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType {
  light,     // Slate Minimal (Light)
  dark,      // Midnight Indigo (Dark)
  aurora,    // Aurora Dream (Emerald Green Dark)
  ocean,     // Ocean Blues (Sapphire Blue Dark)
  sunset,    // Sunset Velvet (Warm Sunset Gold/Pink Dark)
  cyberpunk, // Cyberpunk Wasp (Yellow/Black Dark)
  sakura,    // Sakura Dream (Cherry Blossom Pink Light)
  nebula     // Nebula Purple (Royal Velvet Dark)
}

enum AppFontStyle {
  modern,  // Poppins (English) + Hind Siliguri (Bengali)
  clean,   // Roboto (English) + Noto Sans Bengali (Bengali)
  classic  // Lora (English) + Anek Bangla (Bengali)
}

enum AppLayoutStyle {
  classic,      // Classic Vintage (Current layout style)
  glassmorphism,// Glassmorphic Mirror (Aesthetic translucent)
  neumorphic,   // Neumorphic Soft (Soft 3D physical look)
  neon          // Futuristic Neon (Glowing borders & shadows)
}

class ThemeManager extends ChangeNotifier {
  static const String _themeKey = "theme_type";
  static const String _fontKey = "font_style";
  static const String _layoutKey = "layout_style";
  
  // Singleton instance
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  AppThemeType _currentTheme = AppThemeType.light;
  AppFontStyle _currentFontStyle = AppFontStyle.modern;
  AppLayoutStyle _currentLayoutStyle = AppLayoutStyle.classic;

  AppThemeType get currentTheme => _currentTheme;
  AppFontStyle get currentFontStyle => _currentFontStyle;
  AppLayoutStyle get currentLayoutStyle => _currentLayoutStyle;

  // Backward compatibility getters
  ThemeMode get themeMode => (_currentTheme == AppThemeType.light || _currentTheme == AppThemeType.sakura) ? ThemeMode.light : ThemeMode.dark;
  bool get isDarkMode => !(_currentTheme == AppThemeType.light || _currentTheme == AppThemeType.sakura);

  /// Load theme, font, and layout style from local storage
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load theme
    final themeString = prefs.getString(_themeKey);
    if (themeString != null) {
      _currentTheme = AppThemeType.values.firstWhere(
        (t) => t.name == themeString,
        orElse: () => AppThemeType.light,
      );
    } else {
      // Check legacy theme_mode key
      final legacyString = prefs.getString("theme_mode");
      if (legacyString == 'dark') {
        _currentTheme = AppThemeType.dark;
      } else {
        _currentTheme = AppThemeType.light;
      }
    }

    // Load font style
    final fontString = prefs.getString(_fontKey);
    if (fontString != null) {
      _currentFontStyle = AppFontStyle.values.firstWhere(
        (f) => f.name == fontString,
        orElse: () => AppFontStyle.modern,
      );
    }

    // Load layout style
    final layoutString = prefs.getString(_layoutKey);
    if (layoutString != null) {
      _currentLayoutStyle = AppLayoutStyle.values.firstWhere(
        (l) => l.name == layoutString,
        orElse: () => AppLayoutStyle.classic,
      );
    }

    notifyListeners();
  }

  /// Change theme to a specific AppThemeType
  Future<void> setTheme(AppThemeType type) async {
    _currentTheme = type;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, type.name);
  }

  /// Change font style to a specific AppFontStyle
  Future<void> setFontStyle(AppFontStyle style) async {
    _currentFontStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, style.name);
  }

  /// Change layout style to a specific AppLayoutStyle
  Future<void> setLayoutStyle(AppLayoutStyle style) async {
    _currentLayoutStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutKey, style.name);
  }

  /// Toggle theme between Light and Dark (for backward compatibility)
  Future<void> toggleTheme(bool isDark) async {
    await setTheme(isDark ? AppThemeType.dark : AppThemeType.light);
  }

  /// Get the current ThemeData based on active settings
  ThemeData get currentThemeData => getThemeData(_currentTheme);

  /// Theme data builder
  ThemeData getThemeData(AppThemeType type) {
    ColorScheme colorScheme;
    Color cardColor;
    Color inputColor;
    Brightness brightness;

    switch (type) {
      case AppThemeType.light:
        brightness = Brightness.light;
        colorScheme = const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF4F46E5), // Deep Indigo
          onPrimary: Colors.white,
          secondary: Color(0xFF0EA5E9), // Sky Blue
          onSecondary: Colors.white,
          error: Color(0xFFEF4444),
          onError: Colors.white,
          surface: Color(0xFFF8FAFC), // Slate 50
          onSurface: Color(0xFF0F172A), // Slate 900
          onSurfaceVariant: Color(0xFF64748B), // Slate 500
        );
        cardColor = Colors.white;
        inputColor = const Color(0xFFF1F5F9); // Slate 100
        break;

      case AppThemeType.dark:
        brightness = Brightness.dark;
        colorScheme = const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF818CF8), // Lighter Indigo
          onPrimary: Colors.black,
          secondary: Color(0xFF38BDF8), // Lighter Sky Blue
          onSecondary: Colors.black,
          error: Color(0xFFF87171),
          onError: Colors.black,
          surface: Color(0xFF0F172A), // Slate 900
          onSurface: Color(0xFFF8FAFC), // Slate 50
          onSurfaceVariant: Color(0xFF94A3B8), // Slate 400
        );
        cardColor = const Color(0xFF1E293B); // Slate 800
        inputColor = const Color(0xFF1E293B); // Slate 800
        break;

      case AppThemeType.aurora:
        brightness = Brightness.dark;
        colorScheme = const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF10B981), // Mint Green
          onPrimary: Colors.black,
          secondary: Color(0xFF34D399), // Emerald
          onSecondary: Colors.black,
          error: Color(0xFFF87171),
          onError: Colors.black,
          surface: Color(0xFF06231A), // Ultra Deep Green
          onSurface: Color(0xFFECFDF5), // Emerald 50
          onSurfaceVariant: Color(0xFF6EE7B7), // Emerald 300
        );
        cardColor = const Color(0xFF0A3C2C); // Dark Greenish Card
        inputColor = const Color(0xFF0A3C2C);
        break;

      case AppThemeType.ocean:
        brightness = Brightness.dark;
        colorScheme = const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF38BDF8), // Light Blue
          onPrimary: Colors.black,
          secondary: Color(0xFF60A5FA), // Soft Blue
          onSecondary: Colors.black,
          error: Color(0xFFF87171),
          onError: Colors.black,
          surface: Color(0xFF0F1E36), // Deep Oceanic Blue
          onSurface: Color(0xFFF0F9FF), // Sky 50
          onSurfaceVariant: Color(0xFF93C5FD), // Blue 300
        );
        cardColor = const Color(0xFF172E54); // Deep Navy Card
        inputColor = const Color(0xFF172E54);
        break;

      case AppThemeType.sunset:
        brightness = Brightness.dark;
        colorScheme = const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFF43F5E), // Sunset Rose Pink
          onPrimary: Colors.white,
          secondary: Color(0xFFF59E0B), // Sunset Gold
          onSecondary: Colors.black,
          error: Color(0xFFF87171),
          onError: Colors.black,
          surface: Color(0xFF241216), // Warm Chocolate Dark
          onSurface: Color(0xFFFFF1F2), // Rose 50
          onSurfaceVariant: Color(0xFFFDA4AF), // Rose 300
        );
        cardColor = const Color(0xFF3D1E25); // Warm Rose Card
        inputColor = const Color(0xFF3D1E25);
        break;

      case AppThemeType.cyberpunk:
        brightness = Brightness.dark;
        colorScheme = const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFFFD700), // Wasp Yellow
          onPrimary: Colors.black,
          secondary: Color(0xFFFF9100), // Neon Orange
          onSecondary: Colors.black,
          error: Color(0xFFEF4444),
          onError: Colors.white,
          surface: Color(0xFF0D0D0D), // Jet Black
          onSurface: Colors.white,
          onSurfaceVariant: Color(0xFFFFD700),
        );
        cardColor = const Color(0xFF1A1A1A); // Dark Card
        inputColor = const Color(0xFF1A1A1A);
        break;

      case AppThemeType.sakura:
        brightness = Brightness.light;
        colorScheme = const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFFEC4899), // Sakura Pink
          onPrimary: Colors.white,
          secondary: Color(0xFFF472B6), // Light Pink
          onSecondary: Color(0xFF4C0519), // Deep Maroon
          error: Color(0xFFEF4444),
          onError: Colors.white,
          surface: Color(0xFFFFF5F7), // Pale Pink-White
          onSurface: Color(0xFF4C0519), // Deep Maroon Text
          onSurfaceVariant: Color(0xFF9D174D),
        );
        cardColor = Colors.white;
        inputColor = const Color(0xFFFCE7F3);
        break;

      case AppThemeType.nebula:
        brightness = Brightness.dark;
        colorScheme = const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFA855F7), // Nebula Purple
          onPrimary: Colors.white,
          secondary: Color(0xFFEC4899), // Orchid Pink
          onSecondary: Colors.white,
          error: Color(0xFFEF4444),
          onError: Colors.white,
          surface: Color(0xFF120E2E), // Space Purple
          onSurface: Color(0xFFF3E8FF), // Lavender Text
          onSurfaceVariant: Color(0xFFC084FC),
        );
        cardColor = const Color(0xFF1E1642);
        inputColor = const Color(0xFF1E1642);
        break;
    }

    final TextTheme baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    TextTheme textTheme;
    List<String> fallback;

    switch (_currentFontStyle) {
      case AppFontStyle.modern:
        fallback = [GoogleFonts.hindSiliguri().fontFamily!];
        textTheme = GoogleFonts.poppinsTextTheme(baseTextTheme);
        break;
      case AppFontStyle.clean:
        fallback = [GoogleFonts.notoSansBengali().fontFamily!];
        textTheme = GoogleFonts.robotoTextTheme(baseTextTheme);
        break;
      case AppFontStyle.classic:
        fallback = [GoogleFonts.anekBangla().fontFamily!];
        textTheme = GoogleFonts.loraTextTheme(baseTextTheme);
        break;
    }

    // Dynamic builders based on Layout Style
    CardThemeData cardTheme;
    ElevatedButtonThemeData elevatedButtonTheme;
    InputDecorationTheme inputDecorationTheme;

    switch (_currentLayoutStyle) {
      case AppLayoutStyle.classic:
        cardTheme = CardThemeData(
          elevation: 8,
          shadowColor: brightness == Brightness.light ? const Color(0x1A000000) : const Color(0x33000000),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          color: cardColor,
        );
        elevatedButtonTheme = ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 4,
            shadowColor: colorScheme.primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        );
        inputDecorationTheme = InputDecorationTheme(
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16.0)), borderSide: BorderSide.none),
          filled: true,
          fillColor: inputColor,
          labelStyle: TextStyle(color: brightness == Brightness.light ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          hintStyle: TextStyle(color: brightness == Brightness.light ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          prefixIconColor: brightness == Brightness.light ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          suffixIconColor: brightness == Brightness.light ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        );
        break;

      case AppLayoutStyle.glassmorphism:
        final glassColor = brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.25);
        final glassBorderColor = brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.6)
            : colorScheme.onSurface.withValues(alpha: 0.12);

        cardTheme = CardThemeData(
          elevation: 0,
          color: glassColor,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            side: BorderSide(color: glassBorderColor, width: 1.5),
          ),
        );
        elevatedButtonTheme = ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary.withValues(alpha: 0.3),
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4), width: 1),
            ),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        );
        inputDecorationTheme = InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
            borderSide: BorderSide(color: glassBorderColor, width: 1),
          ),
          filled: true,
          fillColor: glassColor,
          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          prefixIconColor: colorScheme.onSurfaceVariant,
          suffixIconColor: colorScheme.onSurfaceVariant,
        );
        break;

      case AppLayoutStyle.neumorphic:
        final shadowColorDark = brightness == Brightness.light ? Colors.grey.shade300 : Colors.black.withValues(alpha: 0.8);
        
        cardTheme = CardThemeData(
          elevation: 4,
          shadowColor: shadowColorDark,
          color: cardColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
        );
        elevatedButtonTheme = ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cardColor,
            foregroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 5,
            shadowColor: shadowColorDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        );
        inputDecorationTheme = InputDecorationTheme(
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20.0)), borderSide: BorderSide.none),
          filled: true,
          fillColor: inputColor,
          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          prefixIconColor: colorScheme.onSurfaceVariant,
          suffixIconColor: colorScheme.onSurfaceVariant,
        );
        break;

      case AppLayoutStyle.neon:
        cardTheme = CardThemeData(
          elevation: 12,
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
          color: brightness == Brightness.light ? Colors.grey.shade50 : const Color(0xFF090D16),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        );
        elevatedButtonTheme = ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 10,
            shadowColor: colorScheme.primary.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.secondary, width: 1.5),
            ),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        );
        inputDecorationTheme = InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(color: colorScheme.secondary, width: 2),
          ),
          filled: true,
          fillColor: brightness == Brightness.light ? Colors.white : const Color(0xFF090D16),
          labelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          prefixIconColor: colorScheme.primary,
          suffixIconColor: colorScheme.primary,
        );
        break;
    }

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: textTheme.apply(
        fontFamilyFallback: fallback,
        bodyColor: brightness == Brightness.light ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        displayColor: colorScheme.onSurface,
      ),
      cardTheme: cardTheme,
      inputDecorationTheme: inputDecorationTheme,
      elevatedButtonTheme: elevatedButtonTheme,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Get custom card/container decoration based on active layout style
  static BoxDecoration getCardDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = ThemeManager();
    final isDark = theme.brightness == Brightness.dark;
    
    switch (themeManager.currentLayoutStyle) {
      case AppLayoutStyle.classic:
        return BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33000000) : const Color(0x1A000000),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        );
      case AppLayoutStyle.glassmorphism:
        final glassColor = isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.4);
        final glassBorderColor = isDark
            ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.6);
        return BoxDecoration(
          color: glassColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glassBorderColor, width: 1.5),
        );
      case AppLayoutStyle.neumorphic:
        final shadowColorDark = isDark ? Colors.black.withValues(alpha: 0.8) : Colors.grey.shade300;
        final shadowColorLight = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        return BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: shadowColorDark,
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: shadowColorLight,
              blurRadius: 8,
              offset: const Offset(-4, -4),
            ),
          ],
        );
      case AppLayoutStyle.neon:
        return BoxDecoration(
          color: isDark ? const Color(0xFF090D16) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        );
    }
  }
}

