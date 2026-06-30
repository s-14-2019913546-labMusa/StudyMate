import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'ai_service.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Search state
  bool _isLoading = false;
  Map<String, dynamic>? _searchResult;
  String? _geminiApiKey;

  // Favorites state
  Map<String, List<Map<String, dynamic>>> _groupedFavorites = {};
  bool _isLoadingFavorites = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadApiKey();
    _listenToFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pronounce(String word) async {
    if (word.trim().isEmpty) return;
    try {
      final url = 'https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encodeComponent(word.trim())}';
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Error pronouncing word: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play pronunciation: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadApiKey() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _geminiApiKey = doc.data()?['geminiApiKey'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading API key in dictionary: $e');
    }
  }

  void _listenToFavorites() {
    if (_currentUser == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('favorite_words')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final timestamp = data['timestamp'] as Timestamp?;
        final dateStr = timestamp != null
            ? DateFormat('EEEE, MMMM dd, yyyy').format(timestamp.toDate())
            : 'Unspecified Date';
        if (!grouped.containsKey(dateStr)) {
          grouped[dateStr] = [];
        }
        grouped[dateStr]!.add(data);
      }
      if (mounted) {
        setState(() {
          _groupedFavorites = grouped;
          _isLoadingFavorites = false;
        });
      }
    });
  }

  Future<void> _searchWord(String word) async {
    if (word.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _searchResult = null;
    });

    try {
      final result = await AIService.searchDictionaryWord(word.trim(), _geminiApiKey);
      if (mounted) {
        setState(() {
          _searchResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load word: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> wordData) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add favorites.')),
      );
      return;
    }

    final docId = wordData['word'].toString().toLowerCase().trim();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('favorite_words')
        .doc(docId);

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${wordData['word']}" removed from Favorites.')),
        );
      }
    } else {
      await docRef.set({
        'word': wordData['word'],
        'pronunciation': wordData['pronunciation'],
        'ipa': wordData['ipa'],
        'partOfSpeech': wordData['partOfSpeech'],
        'bengaliMeaning': wordData['bengaliMeaning'],
        'definition': wordData['definition'],
        'example': wordData['example'],
        'exampleBengali': wordData['exampleBengali'],
        'synonyms': wordData['synonyms'] ?? [],
        'timestamp': FieldValue.serverTimestamp(),
        'grade': null,
        'memorizedAt': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${wordData['word']}" added to Favorites!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bilingual Dictionary', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.search_rounded), text: 'Search'),
            Tab(icon: Icon(Icons.favorite_rounded), text: 'Favorites'),
            Tab(icon: Icon(Icons.psychology_rounded), text: 'Memorizing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildFavoritesTab(),
          _buildMemorizingTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: Search Tab
  // ==========================================
  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekly revision reminder banner if there are favorites
          if (_groupedFavorites.isNotEmpty) _buildWeeklyRevisionReminderBanner(),

          // Search Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter English word...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest ?? Theme.of(context).cardColor,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _searchWord,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _searchWord(_searchCtrl.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                child: const Icon(Icons.search_rounded),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Suggestion list when empty
          if (_searchResult == null && !_isLoading) ...[
            Text(
              'Suggestions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Knowledge', 'Success', 'Study', 'Persistence', 'Curiosity'].map((w) {
                return ActionChip(
                  label: Text(w),
                  onPressed: () {
                    _searchCtrl.text = w;
                    _searchWord(w);
                  },
                );
              }).toList(),
            ),
          ],

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Searching and translating...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          if (_searchResult != null && !_isLoading) ...[
            _buildResultCard(_searchResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyRevisionReminderBanner() {
    // Basic heuristics: check if any words were added in the last 7 days
    int recentCount = 0;
    _groupedFavorites.forEach((date, words) {
      for (var w in words) {
        final ts = w['timestamp'] as Timestamp?;
        if (ts != null) {
          final diff = DateTime.now().difference(ts.toDate()).inDays;
          if (diff <= 7) recentCount++;
        }
      }
    });

    if (recentCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notification_important_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Revision Reminder!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'You have added $recentCount words this week. Let\'s practice them in the Memorizing tab!',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            onPressed: () => _tabController.animateTo(2),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final word = data['word'] ?? '';
    final ipa = data['ipa'] ?? '';
    final pronunciation = data['pronunciation'] ?? '';
    final partOfSpeech = data['partOfSpeech'] ?? '';
    final bengaliMeaning = data['bengaliMeaning'] ?? '';
    final definition = data['definition'] ?? '';
    final example = data['example'] ?? '';
    final exampleBengali = data['exampleBengali'] ?? '';
    final synonyms = List<String>.from(data['synonyms'] ?? []);

    return StreamBuilder<DocumentSnapshot>(
      stream: _currentUser != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser.uid)
              .collection('favorite_words')
              .doc(word.toString().toLowerCase().trim())
              .snapshots()
          : null,
      builder: (context, snapshot) {
        final isFav = snapshot.hasData && snapshot.data!.exists;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Word Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            word,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                ipa,
                                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                              if (pronunciation.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '($pronunciation)',
                                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded, color: Colors.indigo, size: 28),
                          onPressed: () => _pronounce(word),
                        ),
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? Colors.red : Colors.grey,
                            size: 28,
                          ),
                          onPressed: () => _toggleFavorite(data),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Bengali Meaning
                _buildDetailRow('বাংলা অর্থ (Bengali Meaning):', bengaliMeaning, isHighlighted: true),
                const SizedBox(height: 16),

                // Parts of Speech
                _buildDetailRow('পার্টস অফ স্পিচ (Part of Speech):', partOfSpeech),
                const SizedBox(height: 16),

                // Definition
                _buildDetailRow('সংজ্ঞা (Definition):', definition),
                const SizedBox(height: 16),

                // Example
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'উদাহরণ বাক্য (Example):',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      example,
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                    ),
                    if (exampleBengali.isNotEmpty)
                      Text(
                        exampleBengali,
                        style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),

                if (synonyms.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'সমার্থক শব্দ (Synonyms):',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: synonyms.map((s) {
                      return ActionChip(
                        label: Text(s),
                        onPressed: () {
                          _searchCtrl.text = s;
                          _searchWord(s);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 20 : 16,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: Favorites Tab
  // ==========================================
  Widget _buildFavoritesTab() {
    if (_isLoadingFavorites) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_groupedFavorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No favorite words yet. Search and tap (+) to add!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groupedFavorites.keys.length,
      itemBuilder: (context, index) {
        final dateStr = _groupedFavorites.keys.elementAt(index);
        final words = _groupedFavorites[dateStr]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${words.length} words',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Slide Show Button
              ElevatedButton.icon(
                onPressed: () => _openSlideshowDialog(dateStr, words),
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Show Words slideshow'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              ...words.map((w) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    w['word'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${w['partOfSpeech'] ?? ''}  •  ${w['bengaliMeaning'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (w['grade'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: w['grade'] == 'easy'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            w['grade'] == 'easy' ? 'Easy' : 'Hard',
                            style: TextStyle(
                              color: w['grade'] == 'easy' ? Colors.green : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _toggleFavorite(w),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openSlideshowDialog(String day, List<Map<String, dynamic>> words) {
    showDialog(
      context: context,
      builder: (ctx) {
        int index = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final w = words[index];
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(day, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text('${index + 1} of ${words.length}', style: const TextStyle(fontSize: 14)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          w['word'] ?? '',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: Colors.indigo),
                        onPressed: () => _pronounce(w['word'] ?? ''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    w['ipa'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 32),
                  Text(
                    'বাংলা অর্থ: ${w['bengaliMeaning'] ?? ''}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Part of Speech: ${w['partOfSpeech'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    w['example'] ?? '',
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  if (w['exampleBengali'] != null)
                    Text(
                      w['exampleBengali'],
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: index > 0
                          ? () => setDialogState(() => index--)
                          : null,
                      child: const Text('Back'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    TextButton(
                      onPressed: index < words.length - 1
                          ? () => setDialogState(() => index++)
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 3: Memorizing Tab
  // ==========================================
  Widget _buildMemorizingTab() {
    final List<Map<String, dynamic>> allWords = [];
    _groupedFavorites.forEach((date, words) {
      allWords.addAll(words);
    });

    if (allWords.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No words to memorize yet.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Add words to Favorites to start active recall memorizing session.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Stats Card
          _buildMemorizingOverviewCard(allWords),
          const SizedBox(height: 24),

          // Main Memorizing Flashcards Launcher
          ElevatedButton.icon(
            onPressed: () => _startMemorizingSession(allWords),
            icon: const Icon(Icons.flash_on_rounded, size: 28),
            label: const Text('Start Active Recall Session', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 24),

          // Graded word folders grouped by day
          Text(
            'Saved Graded Words',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_groupedFavorites.keys.isEmpty)
            const Text('No graded lists yet.', style: TextStyle(color: Colors.grey))
          else
            ..._groupedFavorites.keys.map((dateStr) {
              final dayWords = _groupedFavorites[dateStr]!;
              final easyList = dayWords.where((w) => w['grade'] == 'easy').toList();
              final hardList = dayWords.where((w) => w['grade'] == 'hard').toList();

              if (easyList.isEmpty && hardList.isEmpty) {
                return const SizedBox.shrink();
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: easyList.isNotEmpty ? () => _showGradedDialog(dateStr, 'Easy', easyList) : null,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text('${easyList.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                    const Text('Easy Words', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: hardList.isNotEmpty ? () => _showGradedDialog(dateStr, 'Hard', hardList) : null,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text('${hardList.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                                    const Text('Hard Words', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMemorizingOverviewCard(List<Map<String, dynamic>> allWords) {
    final gradedCount = allWords.where((w) => w['grade'] != null).length;
    final easyCount = allWords.where((w) => w['grade'] == 'easy').length;
    final hardCount = allWords.where((w) => w['grade'] == 'hard').length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.indigo.shade900,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Memorizing Summary',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$gradedCount / ${allWords.length}',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Words Memorized',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Divider(height: 24, color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMemorizingStatItem('Easy', easyCount, Colors.greenAccent),
                _buildMemorizingStatItem('Hard', hardCount, Colors.redAccent),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMemorizingStatItem(String label, int val, Color color) {
    return Column(
      children: [
        Text('$val', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  void _showGradedDialog(String date, String grade, List<Map<String, dynamic>> words) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$grade Words ($date)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: words.length,
            itemBuilder: (context, index) {
              final w = words[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(w['word'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(w['bengaliMeaning'] ?? ''),
              );
            },
          ),
        ),
      ),
    );
  }

  void _startMemorizingSession(List<Map<String, dynamic>> allWords) {
    final shuffled = List<Map<String, dynamic>>.from(allWords)..shuffle();
    int currentIndex = 0;
    bool isFlipped = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setSessionState) {
            final w = shuffled[currentIndex];
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Session Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            'Word ${currentIndex + 1} of ${shuffled.length}',
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(width: 48), // Spacer
                        ],
                      ),
                      const Spacer(),

                      // Flip Card Wrapper
                      GestureDetector(
                        onTap: () {
                          setSessionState(() {
                            isFlipped = !isFlipped;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.all(24),
                          height: 380,
                          decoration: BoxDecoration(
                            color: isFlipped ? const Color(0xFF1E293B) : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isFlipped) ...[
                                const Icon(Icons.help_outline_rounded, size: 48, color: Colors.white54),
                                const SizedBox(height: 20),
                                Text(
                                  w['word'] ?? '',
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      w['ipa'] ?? '',
                                      style: const TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
                                      onPressed: () => _pronounce(w['word'] ?? ''),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Text(
                                  'Tap card to reveal details',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ] else ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      w['word'] ?? '',
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primaryContainer),
                                      textAlign: TextAlign.center,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up_rounded, color: Colors.amberAccent, size: 20),
                                      onPressed: () => _pronounce(w['word'] ?? ''),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  w['partOfSpeech'] ?? '',
                                  style: const TextStyle(fontSize: 13, color: Colors.amberAccent),
                                ),
                                const Divider(height: 32, color: Colors.white24),
                                Text(
                                  w['bengaliMeaning'] ?? '',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  w['definition'] ?? '',
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  w['example'] ?? '',
                                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white60),
                                  textAlign: TextAlign.center,
                                ),
                                if (w['exampleBengali'] != null)
                                  Text(
                                    w['exampleBengali'],
                                    style: const TextStyle(fontSize: 13, color: Colors.white38),
                                    textAlign: TextAlign.center,
                                  ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Active Grading Buttons (Visible only when flipped)
                      if (isFlipped)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _gradeWord(w['id'], 'easy');
                                  if (currentIndex < shuffled.length - 1) {
                                    setSessionState(() {
                                      currentIndex++;
                                      isFlipped = false;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Session Completed! Excellent work!'), backgroundColor: Colors.green),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Easy (সহজ)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _gradeWord(w['id'], 'hard');
                                  if (currentIndex < shuffled.length - 1) {
                                    setSessionState(() {
                                      currentIndex++;
                                      isFlipped = false;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Session Completed! Revise hard words regularly.'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Hard (কঠিন)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      else
                        const Center(
                          child: Text(
                            'Please tap the card to verify answer first.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _gradeWord(String wordId, String grade) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .collection('favorite_words')
          .doc(wordId)
          .update({
        'grade': grade,
        'memorizedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error grading word: $e');
    }
  }
}
