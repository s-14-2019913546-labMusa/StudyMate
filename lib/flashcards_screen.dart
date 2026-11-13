import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flashcard_study_screen.dart';
import 'deck_dashboard_screen.dart';
import 'widgets/undo_snackbar.dart';
import 'widgets/empty_state.dart';
import 'widgets/skeleton.dart';
import 'language_manager.dart';
import 'ai_service.dart';

class FlashcardDecksScreen extends StatefulWidget {
  const FlashcardDecksScreen({super.key});

  @override
  State<FlashcardDecksScreen> createState() => _FlashcardDecksScreenState();
}

class _FlashcardDecksScreenState extends State<FlashcardDecksScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isGenerating = false;
  String _aiStatusMessage = '';

  // API Key cache
  String? _geminiApiKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _geminiApiKey = doc.data()?['geminiApiKey'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading API Key: $e');
    }
  }

  Future<void> _saveApiKey(String key) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
      'geminiApiKey': key.trim(),
    }, SetOptions(merge: true));

    setState(() {
      _geminiApiKey = key.trim().isEmpty ? null : key.trim();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Gemini API Key saved successfully!'.tr())),
      );
    }
  }

  // AI Mock Generation Database (Fallback when no API Key)
  List<Map<String, String>> _getAICardsForTopic(String topic) {
    final cleanTopic = topic.trim().toLowerCase();

    // Bengali Nazrul cards
    if (cleanTopic.contains('নজরুল') || cleanTopic.contains('nazrul')) {
      return [
        {
          'front': 'কাজী নজরুল ইসলামকে কী উপাধি দেওয়া হয়েছে?',
          'back': 'তাঁকে বাংলাদেশের "জাতীয় কবি" এবং বাংলা সাহিত্যের ইতিহাসে "বিদ্রোহী কবি" উপাধি দেওয়া হয়েছে।'
        },
        {
          'front': 'কাজী নজরুল ইসলামের জন্ম কত সালে এবং কোথায়?',
          'back': 'তিনি ২৪শে মে, ১৮৯৯ সালে ভারতের পশ্চিমবঙ্গের বর্ধমান জেলার চুরুলিয়া গ্রামে জন্মগ্রহণ করেন।'
        },
        {
          'front': 'নজরুলের বিখ্যাত "বিদ্রোহী" কবিতাটি কত সালে প্রকাশিত হয়?',
          'back': '"বিদ্রোহী" কবিতাটি ১৯২১ সালের ডিসেম্বর মাসে রচিত হয় এবং ১৯২২ সালে তাঁর "অগ্নিবীণা" কাব্যের অংশ হিসেবে প্রকাশিত হয়।'
        },
        {
          'front': 'কাজী নজরুল ইসলামের কয়েকটি বিখ্যাত সাহিত্যকর্মের নাম বলুন।',
          'back': 'তাঁর বিখ্যাত কাব্যের মধ্যে রয়েছে অগ্নিবীণা, বিষের বাঁশী, দোলন-চাঁপা। উপন্যাসের মধ্যে বাঁধন হারা, এবং বিখ্যাত নাটক ঝিলিমিলি।'
        },
        {
          'front': 'নজরুল কবে বাংলাদেশে স্থায়ীভাবে আসেন এবং কবে মৃত্যুবরণ করেন?',
          'back': '১৯৭২ সালে স্বাধীন বাংলাদেশের তৎকালীন সরকার তাঁকে সপরিবারে ঢাকায় আনেন। তিনি ২৯শে আগস্ট, ১৯৭৬ সালে ঢাকায় মৃত্যুবরণ করেন।'
        },
      ];
    } else if (cleanTopic.contains('রবীন্দ্রনাথ') || cleanTopic.contains('রবী') || cleanTopic.contains('tagore') || cleanTopic.contains('ঠাকুর')) {
      return [
        {
          'front': 'রবীন্দ্রনাথ ঠাকুর কত সালে নোবেল পুরস্কার লাভ করেন এবং কোন গ্রন্থের জন্য?',
          'back': 'তিনি ১৯১৩ সালে তাঁর বিখ্যাত কাব্যগ্রন্থ "গীতাঞ্জলি" (Song Offerings) এর জন্য প্রথম অ-ইউরোপীয় হিসেবে সাহিত্যে নোবেল পুরস্কার লাভ করেন।'
        },
        {
          'front': 'রবীন্দ্রনাথ ঠাকুরের জন্ম ও মৃত্যু সাল কত?',
          'back': 'তিনি ৭ই মে, ১৮৬১ সালে কলকাতার জোড়াসাঁকোর ঠাকুর পরিবারে জন্মগ্রহণ করেন এবং ৭ই আগস্ট, ১৯৪১ সালে মৃত্যুবরণ করেন।'
        },
        {
          'front': 'রবীন্দ্রনাথ ঠাকুর রচিত কোন কোন গান দুটি দেশের জাতীয় সঙ্গীত হিসেবে গৃহীত হয়েছে?',
          'back': 'ভারতের জাতীয় সঙ্গীত "জনগণমন-অধিনায়ক জয় হে" এবং বাংলাদেশের জাতীয় সঙ্গীত "আমার সোনার বাংলা" রবীন্দ্রনাথ ঠাকুরের রচনা।'
        },
        {
          'front': 'রবীন্দ্রনাথের কয়েকটি বিখ্যাত উপন্যাসের নাম বলুন।',
          'back': 'তাঁর বিখ্যাত উপন্যাসগুলোর মধ্যে চোখের বালি, গোরা, ঘরে বাইরে, এবং শেষের কবিতা অন্যতম।'
        },
        {
          'front': 'শান্তিনিকেতনে রবীন্দ্রনাথ ঠাকুর কর্তৃক প্রতিষ্ঠিত বিখ্যাত বিশ্ববিদ্যালয়ের নাম কী?',
          'back': 'বিশ্বভারতী বিশ্ববিদ্যালয় (Visva-Bharati University), যা ১৯২১ সালে তিনি শান্তিনিকেতনে প্রতিষ্ঠা করেন।'
        },
      ];
    } else if (cleanTopic.contains('flutter') || cleanTopic.contains('dart')) {
      return [
        {
          'front': 'What is Flutter?',
          'back': 'Flutter is an open-source UI software development kit created by Google for building natively compiled applications for mobile, web, and desktop from a single codebase.'
        },
        {
          'front': 'What programming language is used in Flutter?',
          'back': 'Flutter applications are written in Dart, an object-oriented, class-based language with static typing, also developed by Google.'
        },
        {
          'front': 'Difference between Stateless and Stateful widgets?',
          'back': 'StatelessWidgets are immutable and cannot change their state during runtime. StatefulWidgets maintain a mutable state that can trigger a UI redraw when updated using setState().'
        },
        {
          'front': 'What is Hot Reload in Flutter?',
          'back': 'Hot Reload injects updated source code files into the running Dart VM, allowing developers to see code changes instantly in the UI without losing the current app state.'
        },
        {
          'front': 'What is Impeller in Flutter?',
          'back': 'Impeller is Flutter\'s next-generation rendering engine designed to deliver predictable, high-performance graphics and eliminate shader compilation jank.'
        },
      ];
    } else if (cleanTopic.contains('science') || cleanTopic.contains('biology') || cleanTopic.contains('phys') || cleanTopic.contains('chem')) {
      return [
        {
          'front': 'What is the powerhouse of the cell?',
          'back': 'Mitochondria. They are responsible for generating adenosine triphosphate (ATP), the main energy source for cellular functions.'
        },
        {
          'front': 'What is Photosynthesis?',
          'back': 'Photosynthesis is the process used by plants, algae, and certain bacteria to convert light energy (sunlight) into chemical energy (glucose), releasing oxygen as a byproduct.'
        },
        {
          'front': 'What does DNA stand for?',
          'back': 'Deoxyribonucleic Acid. It is a double-helix molecule containing the genetic instructions used in the development, functioning, growth, and reproduction of all known organisms.'
        },
        {
          'front': 'What is the speed of light?',
          'back': 'Approximately 299,792 kilometers per second (or about 186,000 miles per second) in a vacuum.'
        },
        {
          'front': 'What is Gravity?',
          'back': 'Gravity is a fundamental natural force by which all things with mass or energy are brought toward one another, keeping planets in orbit and keeping objects on Earth.'
        },
      ];
    } else if (cleanTopic.contains('history') || cleanTopic.contains('war') || cleanTopic.contains('world')) {
      return [
        {
          'front': 'Who was the first President of the United States?',
          'back': 'George Washington, who served as President from 1789 to 1797.'
        },
        {
          'front': 'When did World War II end?',
          'back': 'World War II ended in 1945, following the unconditional surrender of the Axis powers.'
        },
        {
          'front': 'What was the Renaissance?',
          'back': 'A fervent period of European cultural, artistic, political, and scientific rebirth, spanning roughly from the 14th century to the 17th century.'
        },
        {
          'front': 'Who built the Taj Mahal?',
          'back': 'The Mughal Emperor Shah Jahan built the Taj Mahal in Agra, India, between 1631 and 1648, as a tomb for his favorite wife, Mumtaz Mahal.'
        },
        {
          'front': 'What was the Magna Carta?',
          'back': 'Signed in 1215, it was a royal charter of rights that established the principle that everyone, including the king, is subject to the law, protecting individual liberties.'
        },
      ];
    }

    // Default general learning tips cards
    return [
      {
        'front': 'What is Active Recall?',
        'back': 'Active recall is an efficient learning method that involves testing your memory by actively retrieving information from your brain, rather than passively reading a textbook.'
      },
      {
        'front': 'What is Spaced Repetition?',
        'back': 'Spaced repetition is a learning technique performed with flashcards, where cards are reviewed at increasing intervals (e.g., 1 day, 3 days, 7 days) to strengthen long-term memory retention.'
      },
      {
        'front': 'What is the Pomodoro Technique?',
        'back': 'A time management system that breaks work into intervals, traditionally 25 minutes of studying followed by a 5-minute break, to maintain focus and prevent fatigue.'
      },
      {
        'front': 'What is the Feynman Technique?',
        'back': 'A mental model for learning concepts by explaining them in simple terms, as if you were teaching a child. This helps quickly identify gaps in your own understanding.'
      },
      {
        'front': 'How does sleep affect learning?',
        'back': 'Sleep plays a critical role in memory consolidation. During sleep, your brain processes and stores the information you learned during the day into long-term memory.'
      },
    ];
  }

  // Generation Logic
  Future<void> _generateAIDeck(String topic) async {
    if (currentUser == null || topic.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _aiStatusMessage = _geminiApiKey != null && _geminiApiKey!.isNotEmpty
          ? 'Querying Google Gemini Model...'
          : 'Searching knowledge database...';
    });

    List<Map<String, String>> cardsData = await AIService.generateFlashcards(topic, _geminiApiKey);

    if (cardsData.isEmpty) {
      setState(() {
        _isGenerating = false;
      });
      return;
    }

    final String capitalizedTopic = topic[0].toUpperCase() + topic.substring(1);
    
    final newDeck = {
      'title': capitalizedTopic.length > 24 ? capitalizedTopic.substring(0, 24) : capitalizedTopic,
      'description': 'AI-generated active recall deck for "$topic".',
      'cards': cardsData.map((c) => {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + cardsData.indexOf(c).toString(),
        'front': c['front'],
        'back': c['back'],
        'difficulty': 'medium',
      }).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('flashcard_decks')
        .add(newDeck);

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trx('Generated study deck for "$capitalizedTopic" successfully!', '"$capitalizedTopic" বিষয়ে স্টাডি ডেক তৈরি হয়েছে!')),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  // Add manual deck and cards
  Future<void> _createManualDeck(String title, String description, List<Map<String, String>> manualCards) async {
    if (currentUser == null || title.trim().isEmpty) return;

    final newDeck = {
      'title': title.trim(),
      'description': description.trim(),
      'cards': manualCards.map((c) => {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + manualCards.indexOf(c).toString(),
        'front': c['front']!.trim(),
        'back': c['back']!.trim(),
        'difficulty': 'medium',
      }).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('flashcard_decks')
        .add(newDeck);
  }

  void _processBulkImport(String title, String description, String rawData) {
    if (title.isEmpty || rawData.isEmpty || currentUser == null) return;
    
    List<Map<String, String>> parsedCards = [];
    
    final RegExp qExp = RegExp(r'\{(?:Question|প্রশ্ন)\}', caseSensitive: false);
    final RegExp aExp = RegExp(r'\{(?:Answer|উত্তর)\}', caseSensitive: false);
    
    final List<String> qChunks = rawData.split(qExp);
    
    for (String chunk in qChunks) {
      if (chunk.trim().isEmpty) continue;
      
      final parts = chunk.split(aExp);
      if (parts.length >= 2) {
        String front = parts[0].trim();
        String back = parts.sublist(1).join('\n').trim();
        
        if (front.isNotEmpty && back.isNotEmpty) {
          parsedCards.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_' + parsedCards.length.toString(),
            'front': front,
            'back': back,
            'difficulty': 'medium', // Default
          });
        }
      }
    }
    
    if (parsedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('No valid flashcards found. Use {Question} and {Answer} tags.'.tr())),
      );
      return;
    }
    
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('flashcard_decks')
        .add({
      'title': title,
      'description': description,
      'cards': parsedCards,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(trx('Successfully imported ${parsedCards.length} flashcards!', '${parsedCards.length}টি ফ্ল্যাশকার্ড ইমপোর্ট হয়েছে!'))),
    );
  }

  // Delete Deck
  Future<void> _deleteDeck(String docId) async {
    if (currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('flashcard_decks')
        .doc(docId);
    final backup = (await ref.get()).data();
    await ref.delete();
    showUndoSnackBar(messenger, trx('Deck deleted.', 'ডেক মুছে ফেলা হয়েছে।'), () async {
      if (backup != null) await ref.set(backup);
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _geminiApiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trx('Enter your Gemini API Key from Google AI Studio to enable live AI deck generation for any topic in any language.', 'Google AI Studio থেকে পাওয়া Gemini API Key দিন, তাহলে যেকোনো বিষয়ে AI দিয়ে ডেক বানানো যাবে।'),
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key (AIzaSy...)',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Text(trx('Note: If left empty, the app uses its offline templates (try "Kazi Nazrul" or "Flutter").', 'খালি রাখলে অ্যাপ অফলাইন টেমপ্লেট ব্যবহার করবে (যেমন "Kazi Nazrul" বা "Flutter" লিখে দেখুন)।'),
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trx('Cancel', 'বাতিল')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveApiKey(controller.text);
            },
            child: Text(trx('Save', 'সেভ')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text(trx('Please log in to use Flashcards.', 'ফ্ল্যাশকার্ড ব্যবহার করতে লগইন করুন।'))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(trx('Flashcards', 'ফ্ল্যাশকার্ড'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.vpn_key_rounded,
              color: _geminiApiKey != null && _geminiApiKey!.isNotEmpty
                  ? Colors.purple
                  : Colors.grey,
            ),
            tooltip: 'Configure Gemini API Key',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: _isGenerating
          ? _buildAILoadingWidget()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .collection('flashcard_decks')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonCardList(padding: EdgeInsets.all(20));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled';
                    final description = data['description'] ?? '';
                    final cards = data['cards'] as List<dynamic>? ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          title: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${cards.length} Cards',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () => _showDeleteConfirmation(doc.id),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                          onTap: () {
                            if (cards.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('This deck has no cards.'.tr())),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeckDashboardScreen(
                                  deckId: doc.id,
                                  deckTitle: title,
                                  allCards: cards,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) {
              return CreateDeckBottomSheet(
                onManualCreate: (title, desc, cards) {
                  _createManualDeck(title, desc, cards);
                },
                onAiGenerate: (topic) {
                  _generateAIDeck(topic);
                },
                onBulkImport: (title, desc, rawData) {
                  _processBulkImport(title, desc, rawData);
                },
              );
            },
          );
        },
        label: Text(trx('New Deck', 'নতুন ডেক'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

Widget _buildEmptyState() {
    void openCreate() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) {
          return CreateDeckBottomSheet(
            onManualCreate: (title, desc, cards) {
              _createManualDeck(title, desc, cards);
            },
            onAiGenerate: (topic) {
              _generateAIDeck(topic);
            },
            onBulkImport: (title, desc, rawData) {
              _processBulkImport(title, desc, rawData);
            },
          );
        },
      );
    }

    return EmptyStateGuide(
      icon: Icons.style_rounded,
      color: Colors.purpleAccent,
      title: trx('No decks yet', 'এখনো কোনো ডেক নেই'),
      message: trx(
        'A flashcard has a question on the front and the answer on the back. Flip, check yourself, repeat.',
        'ফ্ল্যাশকার্ডের সামনে প্রশ্ন, পেছনে উত্তর। উল্টে দেখুন, নিজেকে যাচাই করুন, বারবার পড়ুন।',
      ),
      exampleTitle: trx('Example deck: "Bangladesh basics"', 'উদাহরণ ডেক: "বাংলাদেশ বিষয়াবলি"'),
      exampleLines: [
        trx('Front: Year of the Language Movement? → Back: 1952', 'সামনে: ভাষা আন্দোলন কোন সালে? → পেছনে: ১৯৫২'),
        trx('Front: Largest mangrove forest? → Back: Sundarbans', 'সামনে: বিশ্বের বৃহত্তম ম্যানগ্রোভ বন? → পেছনে: সুন্দরবন'),
        trx('Or let AI make cards from any topic', 'অথবা যেকোনো বিষয় লিখে AI দিয়ে কার্ড বানান'),
      ],
      actionLabel: trx('Create your first deck', 'প্রথম ডেকটা বানান'),
      onAction: openCreate,
    );
  }

  Widget _buildAILoadingWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ]
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              strokeWidth: 6,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'StudyMate AI',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _aiStatusMessage,
              key: ValueKey<String>(_aiStatusMessage),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trx('Delete Deck?', 'ডেক মুছবেন?')),
        content: Text(trx('Are you sure you want to delete this study deck?', 'আপনি কি এই ফ্ল্যাশকার্ড ডেকটি মুছে ফেলতে চান?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDeck(docId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Separate StatefulWidget for Bottom Sheet Content
// Prevents controller re-initialization on keyboard/rebuild state changes
// -------------------------------------------------------------
class CreateDeckBottomSheet extends StatefulWidget {
  final Function(String, String, List<Map<String, String>>) onManualCreate;
  final Function(String) onAiGenerate;
  final Function(String, String, String) onBulkImport;

  const CreateDeckBottomSheet({
    super.key,
    required this.onManualCreate,
    required this.onAiGenerate,
    required this.onBulkImport,
  });

  @override
  State<CreateDeckBottomSheet> createState() => _CreateDeckBottomSheetState();
}

class _CreateDeckBottomSheetState extends State<CreateDeckBottomSheet> {
  // Manual Deck text controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Manual Cards list controllers
  final List<TextEditingController> _questionControllers = [];
  final List<TextEditingController> _answerControllers = [];

  // Bulk Import text controller
  final TextEditingController _bulkTextController = TextEditingController();

  // AI Generator topic controller
  final TextEditingController _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start with 2 empty manual cards
    _addManualCard();
    _addManualCard();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _topicController.dispose();
    _bulkTextController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addManualCard() {
    setState(() {
      _questionControllers.add(TextEditingController());
      _answerControllers.add(TextEditingController());
    });
  }

  void _removeManualCard(int index) {
    if (_questionControllers.length <= 1) return;
    setState(() {
      _questionControllers[index].dispose();
      _answerControllers[index].dispose();
      _questionControllers.removeAt(index);
      _answerControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.paste_rounded), text: 'Bulk Import'),
                  Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'AI Generator'),
                  Tab(icon: Icon(Icons.edit_note_rounded), text: 'Create Manually'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBulkImportTab(),
                    _buildAITab(),
                    _buildManualTab(),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAITab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trx('AI Study Deck Generator', 'AI দিয়ে ডেক তৈরি'),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Type in a prompt (e.g. "কাজি নজরুল ইসলাম নিয়ে ৫টি প্রশ্নোত্তর বানাও" or "Flutter hooks") and StudyMate AI will compile them.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              hintText: 'Enter topic name (e.g., কাজি নজরুল)',
              prefixIcon: Icon(Icons.psychology_rounded),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              final topic = _topicController.text;
              if (topic.trim().isEmpty) return;
              Navigator.pop(context); // Close sheet
              widget.onAiGenerate(topic);
            },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(trx('Generate Flashcards', 'ফ্ল্যাশকার্ড বানান')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        ],
      ),
    );
  }

  void _showAIPromptAdvice(BuildContext context) {
    const promptText = 
'''Act as an expert flashcard creator. I need to study [TOPIC]. Create [NUMBER] flashcards for me. 
Format the output EXACTLY like this without any markdown formatting or extra text:

{Question}
[Your question here]
{Answer}
[Your answer here]
''';

    const promptTextBn = 
'''আমি [TOPIC] নিয়ে পড়াশোনা করছি। আমাকে [NUMBER] টি গুরুত্বপূর্ণ প্রশ্ন ও উত্তর দাও।
দয়া করে নিচের ফরম্যাটটি হুবহু মেনে চলবে। অন্য কোনো টেক্সট বা মার্কডাউন দেবে না:

{প্রশ্ন}
[আপনার প্রশ্ন]
{উত্তর}
[আপনার উত্তর]
''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.tips_and_updates_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text(trx('AI Prompt Guide', 'AI প্রম্পট গাইড')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trx('Copy the prompt below and paste it into ChatGPT, Gemini, or Claude to generate many questions already formatted for StudyMate.', 'নিচের প্রম্পট কপি করে ChatGPT, Gemini বা Claude-এ দিন, StudyMate-এর ফরম্যাটে অনেক প্রশ্ন বানিয়ে দেবে।'), style: TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 16),
              
              Text(trx('English Prompt:', 'ইংরেজি প্রম্পট:'), style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(promptText, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: promptText));
                    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('English prompt copied!'.tr())));
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(trx('Copy English', 'ইংরেজি কপি')),
                ),
              ),
              
              const Divider(height: 32),
              
              Text(trx('Bangla Prompt:', 'বাংলা প্রম্পট:'), style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(promptTextBn, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: promptTextBn));
                    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Bangla prompt copied!'.tr())));
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(trx('Copy Bangla', 'বাংলা কপি')),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trx('Close', 'বন্ধ')),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trx('Bulk Import Flashcards', 'একসাথে অনেক কার্ড যোগ'),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showAIPromptAdvice(context),
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: Text(trx('Get AI Prompt Guide', 'AI প্রম্পট গাইড দেখুন')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade100,
              foregroundColor: Colors.orange.shade800,
              elevation: 0,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(trx('Use {Question} or {প্রশ্ন} before the question, and {Answer} or {উত্তর} before the answer. Multiple lines (like MCQs) work.', 'প্রশ্নের আগে {প্রশ্ন} বা {Question}, উত্তরের আগে {উত্তর} বা {Answer} লিখুন। MCQ-এর মতো কয়েক লাইনও চলবে।'),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('Example:\n{প্রশ্ন}\nবাংলাদেশের রাজধানী কোথায়?\nক. ঢাকা\nখ. সিলেট\n{উত্তর}\nক. ঢাকা', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Deck Title', prefixIcon: Icon(Icons.title_rounded)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bulkTextController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste questions and answers here...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final title = _titleController.text;
              final rawText = _bulkTextController.text;
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please enter a deck title.'.tr())));
                return;
              }
              if (rawText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Please paste some text.'.tr())));
                return;
              }
              Navigator.pop(context);
              widget.onBulkImport(title, _descController.text, rawText);
            },
            icon: const Icon(Icons.done_all_rounded),
            label: Text(trx('Import Cards', 'কার্ড যোগ করুন')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trx('Create Deck Manually', 'নিজে ডেক বানান'),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Deck Title',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cards (${_questionControllers.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton.icon(
                onPressed: _addManualCard,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(trx('Add Card', 'কার্ড যোগ')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Render card input fields
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questionControllers.length,
            itemBuilder: (context, idx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Card ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        if (_questionControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeManualCard(idx),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _questionControllers[idx],
                      decoration: const InputDecoration(hintText: 'Front (Question)', filled: false),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answerControllers[idx],
                      decoration: const InputDecoration(hintText: 'Back (Answer)', filled: false),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final title = _titleController.text;
              if (title.trim().isEmpty) return;

              final List<Map<String, String>> manualCards = [];
              for (var i = 0; i < _questionControllers.length; i++) {
                final q = _questionControllers[i].text.trim();
                final a = _answerControllers[i].text.trim();
                if (q.isNotEmpty && a.isNotEmpty) {
                  manualCards.add({'front': q, 'back': a});
                }
              }

              if (manualCards.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Please add at least one complete card.'.tr())),
                );
                return;
              }

              Navigator.pop(context); // Close sheet
              widget.onManualCreate(title, _descController.text, manualCards);
            },
            child: Text(trx('Create Study Deck', 'ডেক তৈরি করুন')),
          ),
        ],
      ),
    );
  }
}
