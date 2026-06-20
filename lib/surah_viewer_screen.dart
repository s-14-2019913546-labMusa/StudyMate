import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SurahViewerScreen extends StatefulWidget {
  final int surahNumber;
  final String surahNameBangla;
  final String surahNameEnglish;
  final String surahNameArabic;
  final String revelationType;
  final int totalAyahs;

  const SurahViewerScreen({
    super.key,
    required this.surahNumber,
    required this.surahNameBangla,
    required this.surahNameEnglish,
    required this.surahNameArabic,
    required this.revelationType,
    required this.totalAyahs,
  });

  @override
  State<SurahViewerScreen> createState() => _SurahViewerScreenState();
}

class _SurahViewerScreenState extends State<SurahViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _ayahs = [];

  // Settings
  double _arabicFontSize = 24.0;
  bool _showBangla = true;
  bool _showEnglish = false;

  @override
  void initState() {
    super.initState();
    _loadSurahContent();
  }

  Future<void> _loadSurahContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/quran_surah_${widget.surahNumber}.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = json.decode(content);
        setState(() {
          _ayahs = decoded.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        // Fetch from public API
        final results = await Future.wait([
          http.get(Uri.parse("https://api.alquran.cloud/v1/surah/${widget.surahNumber}/quran-simple")),
          http.get(Uri.parse("https://api.alquran.cloud/v1/surah/${widget.surahNumber}/bn.bengali")),
          http.get(Uri.parse("https://api.alquran.cloud/v1/surah/${widget.surahNumber}/en.sahih")),
        ]).timeout(const Duration(seconds: 15));

        if (results[0].statusCode == 200 &&
            results[1].statusCode == 200 &&
            results[2].statusCode == 200) {
          
          final arabicData = json.decode(results[0].body)['data']['ayahs'] as List<dynamic>;
          final bnData = json.decode(results[1].body)['data']['ayahs'] as List<dynamic>;
          final enData = json.decode(results[2].body)['data']['ayahs'] as List<dynamic>;

          final List<Map<String, dynamic>> tempAyahs = [];
          for (int i = 0; i < arabicData.length; i++) {
            tempAyahs.add({
              'numberInSurah': arabicData[i]['numberInSurah'],
              'text': arabicData[i]['text'],
              'bn': bnData[i]['text'],
              'en': enData[i]['text'],
            });
          }

          // Cache locally
          await file.writeAsString(json.encode(tempAyahs));

          setState(() {
            _ayahs = tempAyahs;
            _isLoading = false;
          });
        } else {
          throw Exception("API returned invalid status code");
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "সুরা লোড করতে ব্যর্থ হয়েছে। অনুগ্রহ করে ইন্টারনেট সংযোগ চেক করে আবার চেষ্টা করুন।\n(Error: ${e.toString()})";
      });
    }
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            const goldAccent = Color(0xFFE5B842);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'পড়া কাস্টমাইজ করুন',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Arabic font size slider
                  Row(
                    children: [
                      const Icon(Icons.format_size_rounded, color: goldAccent, size: 20),
                      const SizedBox(width: 12),
                      const Text('আরবি লেখার সাইজ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const Spacer(),
                      Text(
                        '${_arabicFontSize.toInt()} px',
                        style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Slider(
                    value: _arabicFontSize,
                    min: 18.0,
                    max: 36.0,
                    divisions: 9,
                    activeColor: goldAccent,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setModalState(() {
                        _arabicFontSize = val;
                      });
                      setState(() {
                        _arabicFontSize = val;
                      });
                    },
                  ),
                  
                  // Bangla toggle
                  SwitchListTile(
                    title: const Text('বাংলা অনুবাদ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    value: _showBangla,
                    activeThumbColor: goldAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setModalState(() {
                        _showBangla = val;
                      });
                      setState(() {
                        _showBangla = val;
                      });
                    },
                  ),
                  
                  // English toggle
                  SwitchListTile(
                    title: const Text('ইংরেজি অনুবাদ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    value: _showEnglish,
                    activeThumbColor: goldAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setModalState(() {
                        _showEnglish = val;
                      });
                      setState(() {
                        _showEnglish = val;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF0F1E19);
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);
    const textLight = Colors.white;

    final bool showBismillah = widget.surahNumber != 1 && widget.surahNumber != 9;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.surahNameBangla,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textLight),
            ),
            Text(
              '${widget.surahNameEnglish} • ${widget.revelationType == "Meccan" ? "মাক্কী" : "মাদানী"} • ${widget.totalAyahs} আয়াত',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textLight),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: goldAccent),
            tooltip: 'কাস্টমাইজ',
            onPressed: _showSettingsBottomSheet,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadSurahContent,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                          label: const Text('আবার চেষ্টা করুন', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: goldAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _ayahs.length + (showBismillah ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (showBismillah && index == 0) {
                      // Bismillah Calligraphy Header
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24, top: 8),
                        child: const Center(
                          child: Text(
                            "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontFamily: 'serif',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }

                    // Adjusted index if Bismillah is shown
                    final ayahIndex = showBismillah ? index - 1 : index;
                    final ayah = _ayahs[ayahIndex];
                    final int number = ayah['numberInSurah'];
                    String arabicText = ayah['text'];

                    // Remove bismillah prefix from Surah first verse if it starts with it
                    // The API sometimes returns it with the Bismillah prepended for verse 1 (except Fatihah)
                    if (ayahIndex == 0 && widget.surahNumber != 1 && widget.surahNumber != 9) {
                      const bismillahPrefix = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ";
                      if (arabicText.startsWith(bismillahPrefix)) {
                        arabicText = arabicText.substring(bismillahPrefix.length);
                      }
                      const bismillahAlternative = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ";
                      if (arabicText.startsWith(bismillahAlternative)) {
                        arabicText = arabicText.substring(bismillahAlternative.length);
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ayah Number badge and action panel
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Center(
                                  child: Text(
                                    '$number',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                tooltip: 'কপি করুন',
                                onPressed: () {
                                  final copyText = "$arabicText\n"
                                      "${_showBangla ? '${ayah['bn']}\n' : ''}"
                                      "${_showEnglish ? '${ayah['en']}\n' : ''}"
                                      "(${widget.surahNameEnglish}: $number)";
                                  Clipboard.setData(ClipboardData(text: copyText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('আয়াত $number কপি করা হয়েছে!'),
                                      backgroundColor: const Color(0xFF0F3625),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Arabic text
                          Text(
                            arabicText,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _arabicFontSize,
                              height: 1.8,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                            ),
                          ),
                          
                          // Bangla translation
                          if (_showBangla) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 10),
                            Text(
                              ayah['bn'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                          
                          // English translation
                          if (_showEnglish) ...[
                            const SizedBox(height: 12),
                            if (!_showBangla) const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 10),
                            Text(
                              ayah['en'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
