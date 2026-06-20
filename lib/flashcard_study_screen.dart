import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _sessionCompleted = false;

  final Map<String, int> _sessionStats = {
    'easy': 0,
    'medium': 0,
    'hard': 0,
  };

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Future<void> _recordResponse(String difficulty) async {
    _sessionStats[difficulty] = (_sessionStats[difficulty] ?? 0) + 1;

    // Update difficulty of the current card in Firestore
    final currentCard = widget.cards[_currentIndex];
    final String cardId = currentCard['id'];

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
            cardsList[cardIdx]['difficulty'] = difficulty;
            await docRef.update({'cards': cardsList});
          }
        }
      } catch (e) {
        debugPrint('Error updating card difficulty: $e');
      }
    }

    // Go to next card or complete session
    if (_currentIndex < widget.cards.length - 1) {
      setState(() {
        _isFlipped = false;
        _currentIndex++;
      });
    } else {
      setState(() {
        _sessionCompleted = true;
      });
    }
  }

  void _resetSession() {
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
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
        body: Center(child: Text('No cards in this deck.')),
      );
    }

    final currentCard = widget.cards[_currentIndex];
    final progress = (_currentIndex + 1) / widget.cards.length;

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _sessionCompleted 
              ? _buildCompletionView()
              : _buildStudyView(currentCard, progress),
        ),
      ),
    );
  }

  Widget _buildStudyView(Map<String, dynamic> currentCard, double progress) {
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
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${_currentIndex + 1}/${widget.cards.length}',
              style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold),
            )
          ],
        ),
        const SizedBox(height: 40),

        // Flip Card Widget
        Expanded(
          child: GestureDetector(
            onTap: _flipCard,
            child: FlipCardWidget(
              isFlipped: _isFlipped,
              front: _buildCardFace(
                title: 'QUESTION',
                content: currentCard['front'] ?? '',
                color: const Color(0xFF4F46E5), // Indigo
                icon: Icons.help_outline_rounded,
              ),
              back: _buildCardFace(
                title: 'ANSWER',
                content: currentCard['back'] ?? '',
                color: const Color(0xFF0EA5E9), // Sky Blue
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Interactive control area
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isFlipped 
              ? _buildDifficultySelectors()
              : _buildShowAnswerButton(),
        ),
        const SizedBox(height: 20),
      ],
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
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
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
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
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
              Icon(icon, color: Colors.white38, size: 28),
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

  Widget _buildShowAnswerButton() {
    return ElevatedButton(
      key: const ValueKey('show_answer'),
      onPressed: _flipCard,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flip_rounded, size: 20),
          const SizedBox(width: 8),
          Text(
            'Show Answer',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelectors() {
    return Row(
      key: const ValueKey('difficulty_selectors'),
      children: [
        Expanded(
          child: _buildDifficultyButton(
            label: 'Hard',
            color: Colors.redAccent,
            onPressed: () => _recordResponse('hard'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDifficultyButton(
            label: 'Medium',
            color: Colors.orangeAccent,
            onPressed: () => _recordResponse('medium'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDifficultyButton(
            label: 'Easy',
            color: Colors.greenAccent,
            onPressed: () => _recordResponse('easy'),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: color.withOpacity(0.05),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
      ),
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
              color: Colors.greenAccent.withOpacity(0.1),
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
          Text(
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
              border: Border.all(color: Colors.white.withOpacity(0.08)),
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isFlipped ? pi : 0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, angle, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015) // Perspective factor (crucial for 3D look)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: angle < pi / 2
              ? front
              : Transform(
                  // We flip the back card horizontally so it doesn't display mirrored
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: back,
                ),
        );
      },
    );
  }
}
