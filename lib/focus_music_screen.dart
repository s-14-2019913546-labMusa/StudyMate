import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

class FocusMusicScreen extends StatefulWidget {
  const FocusMusicScreen({super.key});

  @override
  State<FocusMusicScreen> createState() => _FocusMusicScreenState();
}

class _FocusMusicScreenState extends State<FocusMusicScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Track details
  final List<Map<String, dynamic>> _tracks = [
    {
      'id': 'lofi',
      'title': 'Lo-Fi Study Beats',
      'subtitle': 'Chill beats for deep focus',
      'icon': Icons.headphones_rounded,
      'color': Colors.purpleAccent,
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    },
    {
      'id': 'rain',
      'title': 'Gentle Rainfall',
      'subtitle': 'Peaceful shower sounds',
      'icon': Icons.water_drop_rounded,
      'color': Colors.blueAccent,
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    },
    {
      'id': 'forest',
      'title': 'Forest Ambience',
      'subtitle': 'Rustling leaves & birds chirping',
      'icon': Icons.park_rounded,
      'color': Colors.greenAccent,
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    },
    {
      'id': 'white_noise',
      'title': 'Deep White Noise',
      'subtitle': 'Steady noise for blocking noise',
      'icon': Icons.air_rounded,
      'color': Colors.tealAccent,
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3',
    },
  ];

  int _selectedTrackIndex = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 0.5;

  // Timer variables
  Timer? _countdownTimer;
  int _timerSecondsRemaining = 0;
  int _selectedTimerMinutes = 0; // 0 means no timer

  // Audio subscription references
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  late AnimationController _soundWaveController;

  @override
  void initState() {
    super.initState();
    _soundWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Initial setup of player configuration
    _audioPlayer.setVolume(_volume);

    // Listen to audio player events
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) {
            _soundWaveController.repeat(reverse: true);
          } else {
            _soundWaveController.stop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _countdownTimer?.cancel();
    _soundWaveController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playTrack(int index) async {
    try {
      if (_selectedTrackIndex == index && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      setState(() {
        _selectedTrackIndex = index;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      final track = _tracks[index];
      await _audioPlayer.play(UrlSource(track['url']));
      await _audioPlayer.setVolume(_volume);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing sound: $e')),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      final track = _tracks[_selectedTrackIndex];
      await _audioPlayer.play(UrlSource(track['url']));
      await _audioPlayer.setVolume(_volume);
    }
  }

  void _setTimer(int minutes) {
    _countdownTimer?.cancel();
    setState(() {
      _selectedTimerMinutes = minutes;
      _timerSecondsRemaining = minutes * 60;
    });

    if (minutes > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_timerSecondsRemaining > 0) {
            _timerSecondsRemaining--;
            // If music is not playing, we still count down but the user might want it playing
          } else {
            _timerSecondsRemaining = 0;
            _selectedTimerMinutes = 0;
            _audioPlayer.pause();
            timer.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Focus timer completed! Music paused.'),
                backgroundColor: Colors.indigo,
              ),
            );
          }
        });
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatTimer(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final activeTrack = _tracks[_selectedTrackIndex];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)], // Premium dark navy/indigo gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Focus Music',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Icon(Icons.music_note_rounded, color: Colors.indigoAccent),
                  ],
                ),
              ),

              // Title and Quote
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Choose your ambient sound to boost concentration and block noise.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Tracks List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _tracks.length,
                  itemBuilder: (context, index) {
                    final track = _tracks[index];
                    final isSelected = index == _selectedTrackIndex;
                    final isCurrentPlaying = isSelected && _isPlaying;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  track['color'].withOpacity(0.25),
                                  track['color'].withOpacity(0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.05),
                                  Colors.white.withOpacity(0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? track['color'].withOpacity(0.4)
                              : Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: track['color'].withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          onTap: () => _playTrack(index),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? track['color'].withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              track['icon'],
                              color: isSelected ? track['color'] : Colors.white60,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            track['title'],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              track['subtitle'],
                              style: GoogleFonts.poppins(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentPlaying
                                  ? track['color']
                                  : Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCurrentPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: isCurrentPlaying ? Colors.white : Colors.white70,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Player Controller Panel (Glassmorphic look)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Currently Playing Track and Wave
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Now Playing',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigoAccent,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeTrack['title'],
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Soundwave Animation
                        SizedBox(
                          height: 30,
                          width: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(4, (index) {
                              return AnimatedBuilder(
                                animation: _soundWaveController,
                                builder: (context, child) {
                                  double factor = 1.0;
                                  if (_isPlaying) {
                                    factor = 0.2 + 0.8 * (index % 2 == 0 
                                      ? _soundWaveController.value 
                                      : 1.0 - _soundWaveController.value);
                                  } else {
                                    factor = 0.15;
                                  }
                                  return Container(
                                    width: 4,
                                    height: 30 * factor,
                                    decoration: BoxDecoration(
                                      color: activeTrack['color'],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress Bar Slider
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: activeTrack['color'],
                              inactiveTrackColor: Colors.white.withOpacity(0.1),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              min: 0.0,
                              max: _duration.inMilliseconds.toDouble() > 0.0
                                  ? _duration.inMilliseconds.toDouble()
                                  : 1.0,
                              value: _position.inMilliseconds.toDouble().clamp(
                                  0.0, 
                                  _duration.inMilliseconds.toDouble() > 0.0 
                                      ? _duration.inMilliseconds.toDouble() 
                                      : 1.0
                              ),
                              onChanged: (val) async {
                                final position = Duration(milliseconds: val.toInt());
                                await _audioPlayer.seek(position);
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Volume control
                    Row(
                      children: [
                        Icon(
                          _volume == 0 
                              ? Icons.volume_mute_rounded 
                              : _volume < 0.4 
                                  ? Icons.volume_down_rounded 
                                  : Icons.volume_up_rounded,
                          color: Colors.white60,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.indigoAccent,
                              inactiveTrackColor: Colors.white.withOpacity(0.1),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _volume,
                              onChanged: (val) async {
                                setState(() => _volume = val);
                                await _audioPlayer.setVolume(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Playback actions (Play/Pause, Timer)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Timer Indicator / Button
                        GestureDetector(
                          onTap: () {
                            _showTimerSelectionDialog();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTimerMinutes > 0
                                  ? Colors.indigo.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedTimerMinutes > 0
                                    ? Colors.indigoAccent.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_rounded,
                                  color: _selectedTimerMinutes > 0
                                      ? Colors.indigoAccent
                                      : Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedTimerMinutes > 0
                                      ? _formatTimer(_timerSecondsRemaining)
                                      : 'Set Timer',
                                  style: GoogleFonts.poppins(
                                    color: _selectedTimerMinutes > 0
                                        ? Colors.indigoAccent
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Play / Pause Button
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [activeTrack['color'], activeTrack['color'].withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeTrack['color'].withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),

                        // Cancel Timer Button (visible if timer active)
                        _selectedTimerMinutes > 0
                            ? GestureDetector(
                                onTap: () => _setTimer(0),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                ),
                              )
                            : const SizedBox(width: 38), // placeholder to balance center
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimerSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1B4B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set Focus Timer',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The focus music will automatically pause when the timer ends.',
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [15, 30, 45, 60].map((minutes) {
                  return ElevatedButton(
                    onPressed: () {
                      _setTimer(minutes);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _selectedTimerMinutes == minutes
                              ? Colors.indigoAccent
                              : Colors.white.withOpacity(0.05),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Text(
                      '$minutes min',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_selectedTimerMinutes > 0)
                TextButton(
                  onPressed: () {
                    _setTimer(0);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel Timer',
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
