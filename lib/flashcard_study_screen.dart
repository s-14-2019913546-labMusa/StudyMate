import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'gamification_service.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;
  final List<dynamic> cards;

  const FlashcardStudyScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    required this.cards,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  final FlutterTts _flutterTts = FlutterTts();

  int _currentIndex = 0;
  bool _sessionCompleted = false;

  final Map<String, int> _sessionStats = {
    'easy': 0,
    'medium': 0,
    'hard': 0,
  };

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _confettiController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _recordResponse(String difficulty, String cardId) async {
    _sessionStats[difficulty] = (_sessionStats[difficulty] ?? 0) + 1;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('flashcard_decks')
            .doc(widget.deckId);

        final docSnap = await docRef.get();
        if (docSnap.exists) {
          final data = docSnap.data() as Map<String, dynamic>;
          final cardsList = List<dynamic>.from(data['cards'] ?? []);
          
          final int cardIdx = cardsList.indexWhere((c) => c['id'] == cardId);
          if (cardIdx != -1) {
            Map<String, dynamic> card = cardsList[cardIdx];
            card['difficulty'] = difficulty;
            
            // SRS Logic
            double ease = (card['ease'] as num?)?.toDouble() ?? 2.5;
            int interval = (card['interval'] as num?)?.toInt() ?? 0;
            
            if (difficulty == 'easy') {
              ease += 0.15;
              interval = interval == 0 ? 4 : (interval * ease).round();
            } else if (difficulty == 'medium') {
              interval = interval == 0 ? 1 : (interval * 1.5).round();
            } else if (difficulty == 'hard') {
              ease = max(1.3, ease - 0.2);
              interval = 1; // review tomorrow
            }
            
            card['ease'] = ease;
            card['interval'] = interval;
            // Set time to beginning of the day so it's due any time that day
            final nextDate = DateTime.now().add(Duration(days: interval));
            final normalizedDate = DateTime(nextDate.year, nextDate.month, nextDate.day);
            card['nextReviewDate'] = Timestamp.fromDate(normalizedDate);

            cardsList[cardIdx] = card;
            await docRef.update({'cards': cardsList});
          }
        }
      } catch (e) {
        debugPrint('Error updating card difficulty: $e');
      }
    }
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    String difficulty = 'medium';
    if (direction == CardSwiperDirection.right) {
      difficulty = 'easy';
    } else if (direction == CardSwiperDirection.left) {
      difficulty = 'hard';
    }

    final cardId = widget.cards[previousIndex]['id'];
    _recordResponse(difficulty, cardId);

    setState(() {
      _currentIndex = currentIndex ?? widget.cards.length;
    });

    if (currentIndex == null || currentIndex >= widget.cards.length) {
      _finishSession();
    }
    return true;
  }

  void _finishSession() {
    setState(() {
      _sessionCompleted = true;
    });
    _confettiController.play();
    _awardFlashcardXP();
  }

  void _resetSession() {
    setState(() {
      _currentIndex = 0;
      _sessionCompleted = false;
      _sessionStats['easy'] = 0;
      _sessionStats['medium'] = 0;
      _sessionStats['hard'] = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: Text('No cards in this deck.', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark premium navy background
      appBar: AppBar(
        title: Text(
          widget.deckTitle,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _sessionCompleted 
                  ? _buildCompletionView()
                  : _buildStudyView(),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 100,
              minBlastForce: 80,
              gravity: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyView() {
    double progress = (_currentIndex) / widget.cards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$_currentIndex/${widget.cards.length}',
              style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold),
            )
          ],
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Swipe Right = Easy  |  Swipe Up = Medium  |  Swipe Left = Hard',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        
        const SizedBox(height: 10),

        // Swiper Stack
        Expanded(
          child: CardSwiper(
            controller: _swiperController,
            cardsCount: widget.cards.length,
            onSwipe: _onSwipe,
            allowedSwipeDirection: const AllowedSwipeDirection.symmetric(horizontal: true, vertical: true),
            numberOfCardsDisplayed: widget.cards.length > 2 ? 3 : widget.cards.length,
            padding: const EdgeInsets.all(0),
            cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
              return SwipableFlashcard(
                cardData: widget.cards[index] as Map<String, dynamic>,
                onSpeak: _speak,
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Control Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: 'btn_hard',
              onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              elevation: 0,
              child: const Icon(Icons.close_rounded, color: Colors.redAccent),
            ),
            FloatingActionButton(
              heroTag: 'btn_medium',
              onPressed: () => _swiperController.swipe(CardSwiperDirection.top),
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              elevation: 0,
              child: const Icon(Icons.remove_rounded, color: Colors.orangeAccent),
            ),
            FloatingActionButton(
              heroTag: 'btn_easy',
              onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
              backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
              elevation: 0,
              child: const Icon(Icons.check_rounded, color: Colors.greenAccent),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCompletionView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 80,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Well Done!',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'You completed your study session for this deck.',
            style: TextStyle(color: Colors.white60, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          // Stats summary
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Summary',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatRow('Easy Cards', _sessionStats['easy'] ?? 0, Colors.greenAccent),
                const Divider(color: Colors.white10, height: 20),
                _buildStatRow('Medium Cards', _sessionStats['medium'] ?? 0, Colors.orangeAccent),
                const Divider(color: Colors.white10, height: 20),
                _buildStatRow('Hard Cards', _sessionStats['hard'] ?? 0, Colors.redAccent),
              ],
            ),
          ),
          const Spacer(),
          
          ElevatedButton(
            onPressed: _resetSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Study Again',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Back to Decks',
              style: GoogleFonts.poppins(color: Colors.white60, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        Text(
          value.toString(),
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Future<void> _awardFlashcardXP() async {
    try {
      final res = await GamificationService.awardXP(
        GamificationService.xpFlashcardDeck,
        reason: 'flashcard_deck_complete',
      );
      if (mounted && res.isNotEmpty) {
        final int xpAwarded = res['xpAwarded'] ?? 0;
        final List<String> newBadges = List<String>.from(res['newBadges'] ?? []);
        String msg = '🎉 Flashcard Study Completed! +$xpAwarded XP';
        if (newBadges.isNotEmpty) {
          msg += '\n🏆 Unlocked: ${newBadges.join(", ")}!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.indigoAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error awarding XP for flashcard: $e');
    }
  }
}

class SwipableFlashcard extends StatefulWidget {
  final Map<String, dynamic> cardData;
  final Function(String) onSpeak;

  const SwipableFlashcard({super.key, required this.cardData, required this.onSpeak});

  @override
  State<SwipableFlashcard> createState() => _SwipableFlashcardState();
}

class _SwipableFlashcardState extends State<SwipableFlashcard> {
  bool _isFlipped = false;

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: FlipCardWidget(
        isFlipped: _isFlipped,
        front: _buildCardFace(
          title: 'QUESTION',
          content: widget.cardData['front'] ?? '',
          color: const Color(0xFF4F46E5),
          icon: Icons.help_outline_rounded,
        ),
        back: _buildCardFace(
          title: 'ANSWER',
          content: widget.cardData['back'] ?? '',
          color: const Color(0xFF0EA5E9),
          icon: Icons.check_circle_outline_rounded,
        ),
      ),
    );
  }

  Widget _buildCardFace({
    required String title,
    required String content,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B), // Slate 800
            const Color(0xFF111827), // Gray 900
          ]
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white70),
                onPressed: () => widget.onSpeak(content),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: SingleChildScrollView(
              child: Text(
                content,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Tap to flip card',
            style: GoogleFonts.poppins(
              color: Colors.white30,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Custom 3D Flip Card Widget
class FlipCardWidget extends StatelessWidget {
  final bool isFlipped;
  final Widget front;
  final Widget back;

  const FlipCardWidget({
    super.key,
    required this.isFlipped,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: isFlipped ? 180 : 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        bool showFront = value < 90;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(value * pi / 180),
          child: showFront
              ? front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: back,
                ),
        );
      },
    );
  }
}
