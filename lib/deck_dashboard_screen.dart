import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'flashcard_study_screen.dart';

class DeckDashboardScreen extends StatelessWidget {
  final String deckId;
  final String deckTitle;
  final List<dynamic> allCards;

  const DeckDashboardScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    required this.allCards,
  });

  @override
  Widget build(BuildContext context) {
    int total = allCards.length;
    int mastered = 0;
    int dueToday = 0;
    int learning = 0;

    final now = DateTime.now();

    List<dynamic> cardsToStudy = [];

    for (var card in allCards) {
      int interval = card['interval'] ?? 0;
      Timestamp? nextReviewTs = card['nextReviewDate'];
      DateTime? nextReview = nextReviewTs?.toDate();

      if (interval >= 21) {
        mastered++;
      } else if (nextReview != null && nextReview.isAfter(now)) {
        learning++;
      }

      if (nextReview == null || nextReview.isBefore(now) || nextReview.isAtSameMomentAs(now)) {
        dueToday++;
        cardsToStudy.add(card);
      }
    }

    // If nothing is due today but we want them to be able to force review, we can provide an option,
    // but typically SRS only gives you what's due.
    bool allDoneForToday = dueToday == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(deckTitle, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Deck Progress',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: total == 0 
                  ? Center(child: Text('No cards in deck', style: TextStyle(color: Colors.white)))
                  : PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 60,
                    sections: [
                      if (mastered > 0)
                        PieChartSectionData(
                          color: Colors.greenAccent,
                          value: mastered.toDouble(),
                          title: '$mastered',
                          radius: 20,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (learning > 0)
                        PieChartSectionData(
                          color: Colors.orangeAccent,
                          value: learning.toDouble(),
                          title: '$learning',
                          radius: 20,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (dueToday > 0)
                        PieChartSectionData(
                          color: Colors.redAccent,
                          value: dueToday.toDouble(),
                          title: '$dueToday',
                          radius: 20,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (total - (mastered + learning + dueToday) > 0)
                        PieChartSectionData(
                          color: Colors.white24,
                          value: (total - (mastered + learning + dueToday)).toDouble(),
                          title: '${total - (mastered + learning + dueToday)}',
                          radius: 20,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildLegend('Due Today', dueToday, Colors.redAccent),
              const SizedBox(height: 12),
              _buildLegend('Learning (Future Review)', learning, Colors.orangeAccent),
              const SizedBox(height: 12),
              _buildLegend('Mastered', mastered, Colors.greenAccent),
              const SizedBox(height: 12),
              _buildLegend('Total Cards', total, Colors.blueAccent),
              
              const Spacer(),
              
              if (allDoneForToday && total > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "You're all caught up for today! Come back tomorrow.",
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: (allDoneForToday || total == 0) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => FlashcardStudyScreen(
                        deckId: deckId,
                        deckTitle: deckTitle,
                        cards: cardsToStudy, // Only pass cards due today!
                      ),
                    ),
                  ).then((_) {
                    // Ideally we should reload the data when returning, 
                    // but the parent screen FlashcardDecksScreen has a StreamBuilder.
                    // Popping this dashboard and letting the user tap it again is easiest for now,
                    // or we pop twice to go back to the list.
                    Navigator.pop(context);
                  });
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  allDoneForToday ? 'No Cards Due' : 'Study Now ($dueToday)',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          ],
        ),
        Text(
          count.toString(),
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
