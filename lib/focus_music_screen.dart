import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart' as fp;

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

  // ── Offline Cache State ───────────────────────────────────────────────────
  String? _downloadingTrackId;
  final Map<String, double> _downloadProgress = {};
  Set<String> _cachedTrackIds = {};

  // ── Custom (Device) Music State ───────────────────────────────────────────
  /// ব্যবহারকারীর device থেকে import করা ট্র্যাকগুলো
  final List<Map<String, String>> _customTracks = []; // {title, path}
  bool _isCustomPlaying = false;   // কাস্টম ট্র্যাক বাজছে কি না
  int _customTrackIndex = -1;      // কোন কাস্টম ট্র্যাক selected

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

    _audioPlayer.setVolume(_volume);

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

    // app খুলতেই কোন ট্র্যাকগুলো cache এ আছে তা জানা
    _checkCachedTracks();
  }

  // ── Cache Helpers ─────────────────────────────────────────────────────────

  /// ট্র্যাকের local cache file path বের করে
  Future<String> _getCachedFilePath(String trackId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/focus_music_$trackId.mp3';
  }

  /// কোন কোন ট্র্যাক ইতিমধ্যে cache এ আছে চেক করে
  Future<void> _checkCachedTracks() async {
    final Set<String> cached = {};
    for (final track in _tracks) {
      final path = await _getCachedFilePath(track['id']);
      if (await File(path).exists()) {
        cached.add(track['id']);
      }
    }
    if (mounted) setState(() => _cachedTrackIds = cached);
  }


  /// ইন্টারনেট থেকে ট্র্যাক download করে device এ save করে
  Future<void> _downloadAndCache(Map<String, dynamic> track, String savePath) async {
    final trackId = track['id'] as String;
    setState(() {
      _downloadingTrackId = trackId;
      _downloadProgress[trackId] = 0.0;
    });

    try {
      final request = http.Request('GET', Uri.parse(track['url']));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _downloadProgress[trackId] = receivedBytes / totalBytes);
        }
      }
      await sink.close();

      if (mounted) {
        setState(() {
          _downloadingTrackId = null;
          _downloadProgress[trackId] = 1.0;
          _cachedTrackIds.add(trackId);
        });
        // Download সম্পন্ন → এখন local file থেকে play
        await _audioPlayer.play(DeviceFileSource(savePath));
        await _audioPlayer.setVolume(_volume);
      }
    } catch (e) {
      // Download ব্যর্থ → সরাসরি URL থেকে stream করার চেষ্টা
      if (mounted) {
        setState(() => _downloadingTrackId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ডাউনলোড ব্যর্থ। ইন্টারনেট থেকে সরাসরি বাজানো হচ্ছে...'),
            backgroundColor: Colors.orange,
          ),
        );
        await _audioPlayer.play(UrlSource(track['url']));
        await _audioPlayer.setVolume(_volume);
      }
    }
  }

  /// সব cache মুছে ফেলা
  Future<void> _clearAllCache() async {
    await _audioPlayer.stop();
    for (final track in _tracks) {
      final path = await _getCachedFilePath(track['id']);
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mounted) {
      setState(() {
        _cachedTrackIds.clear();
        _downloadProgress.clear();
        _isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সব cache মুছে ফেলা হয়েছে।'), backgroundColor: Colors.blueGrey),
      );
    }
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
      final track = _tracks[index];
      final trackId = track['id'] as String;

      if (!_isCustomPlaying && _selectedTrackIndex == index && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      setState(() {
        _isCustomPlaying = false;  // built-in track select করলে custom deselect
        _customTrackIndex = -1;
        _selectedTrackIndex = index;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      final cachePath = await _getCachedFilePath(trackId);
      final cacheFile = File(cachePath);

      if (await cacheFile.exists()) {
        await _audioPlayer.play(DeviceFileSource(cachePath));
        await _audioPlayer.setVolume(_volume);
      } else {
        await _downloadAndCache(track, cachePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সাউন্ড চালাতে সমস্যা: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_isCustomPlaying && _customTrackIndex >= 0) {
        // কাস্টম ট্র্যাক resume
        await _audioPlayer.play(DeviceFileSource(_customTracks[_customTrackIndex]['path']!));
      } else {
        final track = _tracks[_selectedTrackIndex];
        final cachePath = await _getCachedFilePath(track['id']);
        final cacheFile = File(cachePath);
        if (await cacheFile.exists()) {
          await _audioPlayer.play(DeviceFileSource(cachePath));
        } else {
          await _audioPlayer.play(UrlSource(track['url']));
        }
      }
      await _audioPlayer.setVolume(_volume);
    }
  }

  // ── Custom Music Methods ──────────────────────────────────────────────────

  /// Device থেকে audio file pick করে list এ যোগ করে
  Future<void> _pickCustomMusic() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final file in result.files) {
            if (file.path != null) {
              // Duplicate চেক
              final alreadyAdded = _customTracks.any((t) => t['path'] == file.path);
              if (!alreadyAdded) {
                _customTracks.add({'title': file.name, 'path': file.path!});
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ফাইল খুলতে সমস্যা: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// কাস্টম ট্র্যাক play করে
  Future<void> _playCustomTrack(int index) async {
    try {
      // একই কাস্টম ট্র্যাক চলছে → pause
      if (_isCustomPlaying && _customTrackIndex == index && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      setState(() {
        _isCustomPlaying = true;
        _customTrackIndex = index;
        _selectedTrackIndex = -1; // built-in deselect
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      await _audioPlayer.play(DeviceFileSource(_customTracks[index]['path']!));
      await _audioPlayer.setVolume(_volume);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('গান বাজাতে সমস্যা: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// কাস্টম ট্র্যাক list থেকে সরিয়ে দেয়
  void _removeCustomTrack(int index) {
    if (_isCustomPlaying && _customTrackIndex == index) {
      _audioPlayer.stop();
      setState(() {
        _isCustomPlaying = false;
        _customTrackIndex = -1;
        _selectedTrackIndex = 0;
      });
    }
    setState(() {
      _customTracks.removeAt(index);
      if (_customTrackIndex >= _customTracks.length) _customTrackIndex = -1;
    });
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
    // Now playing: কাস্টম হলে custom info, না হলে built-in track info
    final bool showingCustom = _isCustomPlaying && _customTrackIndex >= 0;
    final Color activeColor = showingCustom
        ? Colors.pinkAccent
        : (_selectedTrackIndex >= 0 ? _tracks[_selectedTrackIndex]['color'] : Colors.purpleAccent);
    final String activeTitle = showingCustom
        ? _customTracks[_customTrackIndex]['title']!
        : (_selectedTrackIndex >= 0 ? _tracks[_selectedTrackIndex]['title'] : 'Lo-Fi Study Beats');

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
                    // Cache মুছে ফেলার বাটন
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54),
                      tooltip: 'Cache মুছুন',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cache মুছবেন?'),
                            content: const Text('সব ডাউনলোড করা ট্র্যাক মুছে যাবে এবং পরেরবার আবার ডাউনলোড করতে হবে।'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('মুছুন', style: TextStyle(color: Colors.redAccent))),
                            ],
                          ),
                        );
                        if (confirm == true) _clearAllCache();
                      },
                    ),
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
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Tracks List (Built-in + My Music)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // ── Built-in Tracks ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Ambient Sounds',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...List.generate(_tracks.length, (index) {
                      final track = _tracks[index];
                      final isSelected = !_isCustomPlaying && index == _selectedTrackIndex;
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
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? track['color'].withOpacity(0.4)
                              : Colors.white.withValues(alpha: 0.08),
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
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              onTap: () => _playTrack(index),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? track['color'].withOpacity(0.2)
                                      : Colors.white.withValues(alpha: 0.05),
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0, bottom: 6),
                                    child: Text(
                                      track['subtitle'],
                                      style: GoogleFonts.poppins(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  // ── Cache Status Chip ──
                                  Builder(builder: (_) {
                                    final tid = track['id'] as String;
                                    final isDownloading = _downloadingTrackId == tid;
                                    final isCached = _cachedTrackIds.contains(tid);
                                    final progress = _downloadProgress[tid] ?? 0.0;

                                    if (isDownloading) {
                                      return Row(
                                        children: [
                                          SizedBox(
                                            width: 60,
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.white12,
                                              color: track['color'],
                                              minHeight: 4,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: TextStyle(color: track['color'], fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      );
                                    }
                                    if (isCached) {
                                      return Row(
                                        children: [
                                          const Icon(Icons.offline_pin_rounded, color: Colors.greenAccent, size: 14),
                                          const SizedBox(width: 4),
                                          Text('অফলাইনে সেভ আছে', style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 11)),
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        const Icon(Icons.cloud_download_outlined, color: Colors.white38, size: 14),
                                        const SizedBox(width: 4),
                                        Text('প্রথমবার ডাউনলোড হবে', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCurrentPlaying
                                      ? track['color']
                                      : Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: _downloadingTrackId == track['id']
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: track['color'],
                                        ),
                                      )
                                    : Icon(
                                        isCurrentPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: isCurrentPlaying ? Colors.white : Colors.white70,
                                        size: 22,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                     }),

                    const SizedBox(height: 8),

                    // ── My Music Section ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Music',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickCustomMusic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.pinkAccent, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'গান যোগ করুন',
                                  style: GoogleFonts.poppins(color: Colors.pinkAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // কাস্টম ট্র্যাক লিস্ট
                    if (_customTracks.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.library_music_rounded, color: Colors.white24, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'আপনার পছন্দের গান যোগ করুন',
                              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'MP3, WAV, AAC, M4A, FLAC, OGG সাপোর্ট',
                              style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_customTracks.length, (i) {
                        final ct = _customTracks[i];
                        final isSelected = _isCustomPlaying && i == _customTrackIndex;
                        final isCurrentPlaying = isSelected && _isPlaying;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? [Colors.pinkAccent.withValues(alpha: 0.2), Colors.pinkAccent.withValues(alpha: 0.05)]
                                  : [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.pinkAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onTap: () => _playCustomTrack(i),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.pinkAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: isSelected ? Colors.pinkAccent : Colors.white60,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              ct['title']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'ডিভাইস থেকে আমদানি',
                              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isCurrentPlaying ? Colors.pinkAccent : Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCurrentPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: isCurrentPlaying ? Colors.white : Colors.white70,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _removeCustomTrack(i),
                                  child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Player Controller Panel (Glassmorphic look)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
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
                                  color: showingCustom ? Colors.pinkAccent : Colors.indigoAccent,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeTitle,
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
                                      color: activeColor,
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
                              activeTrackColor: activeColor,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
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
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
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
                                  ? Colors.indigo.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedTimerMinutes > 0
                                    ? Colors.indigoAccent.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.05),
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
                                colors: [activeColor, activeColor.withValues(alpha: 0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.4),
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
                                    color: Colors.red.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
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
      useSafeArea: true,
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
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _selectedTimerMinutes == minutes
                              ? Colors.indigoAccent
                              : Colors.white.withValues(alpha: 0.05),
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
