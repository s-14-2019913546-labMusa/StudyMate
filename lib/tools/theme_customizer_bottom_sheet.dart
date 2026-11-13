import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../daily_routine.dart';
import '../dashboard_screen.dart';
import '../calendar_screen.dart';
import '../focus_music_screen.dart';
import '../flashcards_screen.dart';
import '../dictionary_screen.dart';
import '../ai_service.dart';
import '../revision_147_screen.dart';
import '../islamic_life_screen.dart';
import '../theme_manager.dart';
import '../local_notification_service.dart';
import '../study_analytics_screen.dart';
import '../weekly_overview_screen.dart';
import '../task_history_screen.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import '../study_folder_manager_screen.dart';
import '../special_day_countdown_screen.dart';
import '../daily_diary_screen.dart';
import '../bookmarks_screen.dart';
import '../news_reader_screen.dart';
import '../social_hub_screen.dart';
import '../google_sheet_sync_screen.dart';
import '../multi_sheet_manager_screen.dart';
import '../notifications_hub_screen.dart';
import '../widgets/sound_picker_widget.dart';
import '../tools_screen.dart';

// ==========================================
// Premium Theme Customizer Bottom Sheet
// ==========================================
class ThemeCustomizerBottomSheet extends StatelessWidget {
  const ThemeCustomizerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();

    final List<Map<String, dynamic>> themes = [
      {
        'type': AppThemeType.light,
        'name': 'Slate Minimal',
        'desc': 'Clean, crisp and high-contrast light theme.',
        'primary': const Color(0xFF4F46E5),
        'surface': const Color(0xFFF8FAFC),
        'accent': const Color(0xFF0EA5E9),
        'isDark': false,
      },
      {
        'type': AppThemeType.dark,
        'name': 'Midnight Indigo',
        'desc': 'Relaxing dark theme with indigo accents.',
        'primary': const Color(0xFF818CF8),
        'surface': const Color(0xFF0F172A),
        'accent': const Color(0xFF38BDF8),
        'isDark': true,
      },
      {
        'type': AppThemeType.aurora,
        'name': 'Aurora Dream',
        'desc': 'Emerald green tones for visual relaxation.',
        'primary': const Color(0xFF10B981),
        'surface': const Color(0xFF06231A),
        'accent': const Color(0xFF34D399),
        'isDark': true,
      },
      {
        'type': AppThemeType.ocean,
        'name': 'Ocean Blues',
        'desc': 'Deep sapphire blue that improves focus.',
        'primary': const Color(0xFF38BDF8),
        'surface': const Color(0xFF0F1E36),
        'accent': const Color(0xFF60A5FA),
        'isDark': true,
      },
      {
        'type': AppThemeType.sunset,
        'name': 'Sunset Velvet',
        'desc': 'Warm sunset colors that stimulate memory.',
        'primary': const Color(0xFFF43F5E),
        'surface': const Color(0xFF241216),
        'accent': const Color(0xFFF59E0B),
        'isDark': true,
      },
      {
        'type': AppThemeType.cyberpunk,
        'name': 'Cyberpunk Wasp',
        'desc': 'High-contrast yellow and deep black cyberpunk theme.',
        'primary': const Color(0xFFFFD700),
        'surface': const Color(0xFF0D0D0D),
        'accent': const Color(0xFFFF9100),
        'isDark': true,
      },
      {
        'type': AppThemeType.sakura,
        'name': 'Sakura Dream',
        'desc': 'Soft pastel cherry blossom pink light theme.',
        'primary': const Color(0xFFEC4899),
        'surface': const Color(0xFFFFF5F7),
        'accent': const Color(0xFFF472B6),
        'isDark': false,
      },
      {
        'type': AppThemeType.nebula,
        'name': 'Nebula Purple',
        'desc': 'Cosmic dark theme with neon purple accents.',
        'primary': const Color(0xFFA855F7),
        'surface': const Color(0xFF120E2E),
        'accent': const Color(0xFFEC4899),
        'isDark': true,
      },
    ];

    return ListenableBuilder(
      listenable: themeManager,
      builder: (context, _) {
        final currentTheme = themeManager.currentTheme;
        final theme = Theme.of(context);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull Bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_rounded, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(trx('Theme Customizer', 'থিম বদলান'),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(trx('Select a custom theme to personalize your study environment.', 'নিজের পছন্দের থিম বেছে নিন।'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 20),
  
                // Theme List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: themes.length,
                  itemBuilder: (context, index) {
                    final t = themes[index];
                    final isSelected = currentTheme == t['type'];
  
                    return GestureDetector(
                      onTap: () {
                        themeManager.setTheme(t['type']);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary.withValues(alpha: 0.08) 
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Color Preview Palette
                            Container(
                              width: 50,
                              height: 30,
                              decoration: BoxDecoration(
                                color: t['surface'],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: t['primary'], shape: BoxShape.circle),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: t['accent'], shape: BoxShape.circle),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
  
                            // Text Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (t['name'] as String).tr(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (t['desc'] as String).tr(),
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
  
                            // Checkbox Indicator
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            else
                              Icon(Icons.radio_button_off_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),
  
                // Font Style Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.font_download_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(trx('App Font Style', 'অ্যাপের ফন্ট'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
  
                // Font Style Row Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildFontOptionCard(
                        context, 
                        themeManager, 
                        AppFontStyle.modern, 
                        'Modern Dynamic', 
                        'Aa / অ', 
                        'Poppins & Hind'
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFontOptionCard(
                        context, 
                        themeManager, 
                        AppFontStyle.clean, 
                        'Clean Minimal', 
                        'Aa / অ', 
                        'Roboto & Noto'
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFontOptionCard(
                        context, 
                        themeManager, 
                        AppFontStyle.classic, 
                        'Classic Serif', 
                        'Aa / অ', 
                        'Lora & Anek'
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 16),
  
                // Layout Style Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dashboard_customize_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(trx('App Layout Style', 'অ্যাপের লেআউট'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
  
                // Layout Style Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: [
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.classic, 'Classic Vintage', Icons.layers_outlined),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.glassmorphism, 'Glassmorphism', Icons.blur_on_rounded),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.neumorphic, 'Neumorphic Soft', Icons.filter_hdr_outlined),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.neon, 'Neon Glow', Icons.lightbulb_outline_rounded),
                    _buildLayoutOptionCard(context, themeManager, AppLayoutStyle.iosGlassy, 'iOS Premium', Icons.phone_iphone_rounded),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontOptionCard(
    BuildContext context, 
    ThemeManager themeManager, 
    AppFontStyle style, 
    String title, 
    String previewText, 
    String desc
  ) {
    final isSelected = themeManager.currentFontStyle == style;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => themeManager.setFontStyle(style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              previewText,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOptionCard(
    BuildContext context, 
    ThemeManager themeManager, 
    AppLayoutStyle style, 
    String name, 
    IconData icon
  ) {
    final isSelected = themeManager.currentLayoutStyle == style;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => themeManager.setLayoutStyle(style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, 
              size: 20
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

