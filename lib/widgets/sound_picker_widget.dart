import 'package:flutter/material.dart';
import '../local_notification_service.dart';

class SoundPickerWidget extends StatefulWidget {
  final String selectedSoundKey;
  final String selectedSoundName;
  final Map<String, String> systemSounds;
  final Map<String, String> favoriteSounds;
  final bool isAlarm;
  final ValueChanged<String> onSoundSelected;
  final Color primaryColor;

  const SoundPickerWidget({
    super.key,
    required this.selectedSoundKey,
    required this.selectedSoundName,
    required this.systemSounds,
    required this.favoriteSounds,
    required this.isAlarm,
    required this.onSoundSelected,
    required this.primaryColor,
  });

  @override
  State<SoundPickerWidget> createState() => _SoundPickerWidgetState();
}

class _SoundPickerWidgetState extends State<SoundPickerWidget> {
  bool _isPlayingPreview = false;

  void _togglePreviewSound() async {
    if (_isPlayingPreview) {
      await SoundPlayer.stopAlarm();
      if (mounted) setState(() => _isPlayingPreview = false);
    } else {
      if (mounted) setState(() => _isPlayingPreview = true);
      await SoundPlayer.playNotificationSoundAndVibration(
        soundName: widget.selectedSoundKey,
        volume: 0.8,
        soundEnabled: true,
        vibrationEnabled: true,
        isAlarm: widget.isAlarm,
      );
      // Wait a bit, we don't automatically know when it ends for RawResources.
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isPlayingPreview) {
          setState(() => _isPlayingPreview = false);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_isPlayingPreview) {
      SoundPlayer.stopAlarm();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: onSurfaceVariant.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.selectedSoundName,
              style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isPlayingPreview
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  color: widget.primaryColor,
                  size: 24,
                ),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(right: 8.0),
                onPressed: _togglePreviewSound,
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: widget.primaryColor,
                ),
                onSelected: (String value) {
                  if (_isPlayingPreview) {
                    _togglePreviewSound(); // Stop old preview
                  }
                  widget.onSoundSelected(value);
                },
                itemBuilder: (BuildContext context) {
                  return [
                    // --- System Default Sounds ---
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        'System Defaults',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...widget.systemSounds.entries.map((entry) {
                      final isSelected = entry.key == widget.selectedSoundKey;
                      return PopupMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(entry.value)),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      );
                    }),
                    
                    const PopupMenuDivider(),

                    // --- StudyMate Favorites ---
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        'StudyMate Favorites',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...widget.favoriteSounds.entries.map((entry) {
                      final isSelected = entry.key == widget.selectedSoundKey;
                      return PopupMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.music_note,
                                    size: 16,
                                    color: onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      );
                    }),
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
