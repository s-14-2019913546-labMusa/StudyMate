import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ChatThemeManager {
  static final List<Map<String, dynamic>> themesList = [
    {
      'id': 'default',
      'name': 'Classic (Default)',
      'isImage': false,
      'colors': [Colors.grey, Colors.grey],
    },
    {
      'id': 'midnight',
      'name': 'Midnight Star',
      'isImage': false,
      'colors': [const Color(0xFF141E30), const Color(0xFF243B55)],
    },
    {
      'id': 'ocean',
      'name': 'Ocean Breeze',
      'isImage': false,
      'colors': [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],
    },
    {
      'id': 'forest_path',
      'name': 'Forest Path',
      'isImage': true,
      'path': 'assets/images/forest_path.png',
      'colors': [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
    },
    {
      'id': 'village_evening',
      'name': 'Village Evening',
      'isImage': true,
      'path': 'assets/images/village_evening.png',
      'colors': [const Color(0xFFD84315), const Color(0xFFBF360C)],
    },
    {
      'id': 'starry_night',
      'name': 'Starry Night',
      'isImage': true,
      'path': 'assets/images/starry_night.png',
      'colors': [const Color(0xFF283593), const Color(0xFF1A237E)],
    },
    {
      'id': 'study_desk',
      'name': 'Cozy Study Desk',
      'isImage': true,
      'path': 'assets/images/study_desk.png',
      'colors': [const Color(0xFF5D4037), const Color(0xFF3E2723)],
    },
    {
      'id': 'library',
      'name': 'Mystical Library',
      'isImage': true,
      'path': 'assets/images/library.png',
      'colors': [const Color(0xFF512DA8), const Color(0xFF311B92)],
    },
    {
      'id': 'coffee_shop',
      'name': 'Coffee Corner',
      'isImage': true,
      'path': 'assets/images/coffee_shop.png',
      'colors': [const Color(0xFF795548), const Color(0xFF4E342E)],
    },
  ];

  static BoxDecoration getThemeDecoration(String themeId, bool isDark) {
    final theme = themesList.firstWhere(
      (t) => t['id'] == themeId,
      orElse: () => themesList[0],
    );

    if (theme['isImage'] == true) {
      return BoxDecoration(
        image: DecorationImage(
          image: AssetImage(theme['path']),
          fit: BoxFit.cover,
          colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.darken),
        ),
      );
    } else {
      if (themeId == 'midnight') {
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      } else if (themeId == 'ocean') {
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        );
      } else {
        return BoxDecoration(
          color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        );
      }
    }
  }

  static void showThemeSelector(
    BuildContext context, 
    String currentTheme, 
    Function(String) onThemeSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ThemeSelectorSheet(
          currentTheme: currentTheme,
          onThemeSelected: (selectedTheme) {
            onThemeSelected(selectedTheme);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }
}

class _ThemeSelectorSheet extends StatefulWidget {
  final String currentTheme;
  final Function(String) onThemeSelected;

  const _ThemeSelectorSheet({
    required this.currentTheme,
    required this.onThemeSelected,
  });

  @override
  State<_ThemeSelectorSheet> createState() => _ThemeSelectorSheetState();
}

class _ThemeSelectorSheetState extends State<_ThemeSelectorSheet> {
  late String _previewTheme;

  @override
  void initState() {
    super.initState();
    _previewTheme = widget.currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Preview'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () => widget.onThemeSelected(_previewTheme),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Apply'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: ChatThemeManager.getThemeDecoration(_previewTheme, isDark).copyWith(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDummyMessage(
                      text: "Hello! Did you check out the new themes?",
                      isMe: false,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    _buildDummyMessage(
                      text: "Yes! The live preview is amazing! 🤩",
                      isMe: true,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ChatThemeManager.themesList.length,
              itemBuilder: (context, index) {
                final th = ChatThemeManager.themesList[index];
                final isSelected = th['id'] == _previewTheme;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _previewTheme = th['id'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: Container(
                              decoration: th['isImage'] == true
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: AssetImage(th['path']),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: List<Color>.from(th['colors']),
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 28)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (th['name'] as String).tr(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDummyMessage({required String text, required bool isMe, required ThemeData theme}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : (theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : (theme.brightness == Brightness.dark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

