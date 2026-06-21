import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TasbeehCounterScreen extends StatefulWidget {
  const TasbeehCounterScreen({super.key});

  @override
  State<TasbeehCounterScreen> createState() => _TasbeehCounterScreenState();
}

class _TasbeehCounterScreenState extends State<TasbeehCounterScreen> {
  final List<Map<String, dynamic>> _dhikrList = [
    {'arabic': 'سُبْحَانَ ٱللَّٰهِ', 'bangla': 'সুবহানাল্লাহ', 'meaning': 'Allah is Perfect', 'limit': 33},
    {'arabic': 'ٱلْحَمْدُ لِلَّٰهِ', 'bangla': 'আলহামদুলিল্লাহ', 'meaning': 'All praise is for Allah', 'limit': 33},
    {'arabic': 'ٱللَّٰهُ أَكْبَرُ', 'bangla': 'আল্লাহু আকবার', 'meaning': 'Allah is the Greatest', 'limit': 34},
  ];

  int _currentIndex = 0;
  int _counter = 0;
  int _totalDhikrCount = 0;

  void _incrementCounter() {
    HapticFeedback.lightImpact();
    setState(() {
      _counter++;
      _totalDhikrCount++;
      
      final currentLimit = _dhikrList[_currentIndex]['limit'] as int;
      if (_counter >= currentLimit) {
        _counter = 0;
        _currentIndex = (_currentIndex + 1) % _dhikrList.length;
        HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.vibrate();
        });
      }
    });
  }

  void _resetCounter() {
    HapticFeedback.mediumImpact();
    setState(() {
      _counter = 0;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF0F1E19);
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);
    
    final currentDhikr = _dhikrList[_currentIndex];
    final limit = currentDhikr['limit'] as int;
    final progress = _counter / limit;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: const Text('Tasbeeh Counter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: goldAccent),
            tooltip: 'Reset',
            onPressed: _resetCounter,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: List.generate(_dhikrList.length, (index) {
                  final isSelected = index == _currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _currentIndex = index;
                          _counter = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? goldAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _dhikrList[index]['bangla'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentDhikr['arabic'],
                    style: const TextStyle(
                      color: goldAccent,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentDhikr['bangla'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    currentDhikr['meaning'],
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _incrementCounter,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(goldAccent),
                          ),
                        ),
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardBg,
                            border: Border.all(
                              color: goldAccent.withValues(alpha: 0.2),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: goldAccent.withValues(alpha: 0.08),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_counter',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'LIMIT: $limit',
                                style: const TextStyle(
                                  color: goldAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'আজকের মোট তসবিহ count',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '$_totalDhikrCount',
                    style: const TextStyle(
                      color: goldAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
