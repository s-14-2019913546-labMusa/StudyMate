import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../daily_routine.dart';
import '../dashboard_screen.dart';
import '../calendar_screen.dart';
import '../focus_music_screen.dart';
import '../flashcards_screen.dart';
import '../dictionary_screen.dart';
import '../ai_service.dart';
import '../revision_147_screen.dart';
import '../islamic_life_screen.dart';
import '../theme_manager.dart';
import '../local_notification_service.dart';
import '../study_analytics_screen.dart';
import '../weekly_overview_screen.dart';
import '../task_history_screen.dart';
import '../gamification_service.dart';
import '../language_manager.dart';
import '../study_folder_manager_screen.dart';
import '../special_day_countdown_screen.dart';
import '../daily_diary_screen.dart';
import '../bookmarks_screen.dart';
import '../news_reader_screen.dart';
import '../social_hub_screen.dart';
import '../google_sheet_sync_screen.dart';
import '../multi_sheet_manager_screen.dart';
import '../notifications_hub_screen.dart';
import '../widgets/sound_picker_widget.dart';
import '../tools_screen.dart';

// ==========================================
// 5. Calculator Screen (ক্যালকুলেটর স্ক্রিন)
// ==========================================
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _equation = "";
  String _result = "0";
  bool _shouldReset = false;
  bool _isStandard = true;
  bool _isDegree = true;

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "AC") {
        _equation = "";
        _result = "0";
        _shouldReset = false;
      } else if (buttonText == "⌫") {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        } else if (_equation.isNotEmpty) {
          if (_equation.endsWith("sin(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("cos(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("tan(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("log(")) {
            _equation = _equation.substring(0, _equation.length - 4);
          } else if (_equation.endsWith("ln(")) {
            _equation = _equation.substring(0, _equation.length - 3);
          } else if (_equation.endsWith("√(")) {
            _equation = _equation.substring(0, _equation.length - 2);
          } else {
            _equation = _equation.substring(0, _equation.length - 1);
          }
        }
        _updateLiveResult();
      } else if (buttonText == "=") {
        if (_equation.isNotEmpty) {
          _result = _evaluateEquation(_equation);
          _equation = _result;
          _shouldReset = true;
        }
      } else if (buttonText == "deg" || buttonText == "rad") {
        _isDegree = buttonText == "deg";
        _updateLiveResult();
      } else if (buttonText == "sin" || buttonText == "cos" || buttonText == "tan" || buttonText == "log" || buttonText == "ln") {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        }
        _equation += "$buttonText(";
        _updateLiveResult();
      } else if (buttonText == "√") {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        }
        _equation += "√(";
        _updateLiveResult();
      } else if (buttonText == "+/-") {
        if (_shouldReset) {
          _equation = _result;
          _shouldReset = false;
        }
        _toggleSign();
        _updateLiveResult();
      } else if (_isOperator(buttonText)) {
        if (_shouldReset) {
          _equation = _result;
          _shouldReset = false;
        }
        if (_equation.isEmpty) {
          if (buttonText == "-") {
            _equation = "-";
          }
        } else {
          String lastChar = _equation[_equation.length - 1];
          if (_isOperator(lastChar)) {
            _equation = _equation.substring(0, _equation.length - 1) + buttonText;
          } else {
            _equation += buttonText;
          }
        }
      } else {
        if (_shouldReset) {
          _equation = "";
          _shouldReset = false;
        }
        if (buttonText == ".") {
          if (_equation.isEmpty) {
            _equation = "0.";
          } else {
            String lastChar = _equation[_equation.length - 1];
            if (_isOperator(lastChar)) {
              _equation += "0.";
            } else {
              List<String> parts = _equation.split(RegExp(r'[+\-×÷^]'));
              if (parts.isNotEmpty && !parts.last.contains('.')) {
                _equation += ".";
              }
            }
          }
        } else {
          _equation += buttonText;
        }
        _updateLiveResult();
      }
    });
  }

  bool _isOperator(String char) {
    return char == "+" || char == "-" || char == "×" || char == "÷" || char == "^";
  }

  void _toggleSign() {
    if (_equation.isEmpty) return;
    int i = _equation.length - 1;
    while (i >= 0 && !_isOperator(_equation[i])) {
      i--;
    }
    if (i < 0) {
      if (_equation.startsWith("-")) {
        _equation = _equation.substring(1);
      } else {
        _equation = "-$_equation";
      }
    } else if (i == 0 && _equation[0] == "-") {
      _equation = _equation.substring(1);
    } else {
      String op = _equation[i];
      String left = _equation.substring(0, i);
      String right = _equation.substring(i + 1);
      if (op == "+") {
        _equation = "$left-$right";
      } else if (op == "-") {
        if (i == 0 || _isOperator(_equation[i - 1])) {
          _equation = left + right;
        } else {
          _equation = "$left+$right";
        }
      } else {
        if (right.startsWith("-")) {
          _equation = "$left$op${right.substring(1)}";
        } else {
          _equation = "$left$op-$right";
        }
      }
    }
  }

  void _updateLiveResult() {
    if (_equation.isEmpty) {
      _result = "0";
      return;
    }
    String lastChar = _equation[_equation.length - 1];
    if (!_isOperator(lastChar) && lastChar != "(") {
      String eval = _evaluateEquation(_equation);
      if (eval != "Error") {
        _result = eval;
      }
    }
  }

  String _evaluateEquation(String expr) {
    try {
      if (expr.isEmpty) return "0";
      String sanitized = expr;
      int openCount = 0;
      int closeCount = 0;
      for (int i = 0; i < sanitized.length; i++) {
        if (sanitized[i] == '(') openCount++;
        if (sanitized[i] == ')') closeCount++;
      }
      if (openCount > closeCount) {
        sanitized += ')' * (openCount - closeCount);
      }
      sanitized = sanitized.replaceAll('×', '*').replaceAll('÷', '/');
      final parser = MathParser(sanitized, isDegree: _isDegree);
      double total = parser.parse();
      if (total.isInfinite || total.isNaN) return "Error";
      if (total == total.toInt()) {
        return total.toInt().toString();
      }
      String formatted = total.toStringAsFixed(10);
      if (formatted.contains('.')) {
        formatted = formatted.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      return formatted;
    } catch (e) {
      return "Error";
    }
  }

  Widget _buildButton(String text, {Color? textColor, Color? bgColor, int flex = 1}) {
    final bool isOp = _isOperator(text) || text == "=";
    final bool isSpecial = text == "AC" || text == "⌫" || text == "%" || text == "+/-";
    
    Color defaultBg = isOp 
        ? const Color(0xFFFF9F0A)
        : isSpecial 
            ? const Color(0xFFA5A5A5)
            : const Color(0xFF333333);
            
    Color defaultTextColor = isSpecial ? Colors.black : Colors.white;

    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(4),
        child: AspectRatio(
          aspectRatio: _isStandard 
              ? (flex == 1 ? 1 : 2.1)
              : (flex == 1 ? 1.4 : 3.0),
          child: ElevatedButton(
            onPressed: () => _buttonPressed(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor ?? defaultBg,
              foregroundColor: textColor ?? defaultTextColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
            ),
            child: Text(
              text, 
              style: TextStyle(
                fontSize: text.length > 1 && text != "+/-" ? 18 : 24, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScientificButton(String text, {bool isToggle = false}) {
    Color bgColor = const Color(0xFF2E2E3E);
    Color textColor = Colors.white70;
    
    if (isToggle) {
      bgColor = const Color(0xFF3F51B5);
      textColor = Colors.white;
    }
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: ElevatedButton(
            onPressed: () {
              if (isToggle) {
                _buttonPressed(_isDegree ? 'rad' : 'deg');
              } else {
                _buttonPressed(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: textColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isStandard = label == "Standard";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF333333) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.white24 : Colors.transparent,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.tr(),
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showScientificGuideline(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isBn = LanguageManager().currentLanguage == 'bn';
        final title = isBn ? 'সায়েন্টিফিক ক্যালকুলেটর গাইডলাইন' : 'Scientific Calculator Guideline';
        
        final List<Map<String, String>> guideItems = isBn ? [
          {'title': 'DEG / RAD', 'desc': 'কোণ পরিমাপের একক ডিগ্রি (DEG) বা রেডিয়ানে (RAD) পরিবর্তন করতে ব্যবহার করুন। ডিগ্রি মোডে sin(30) = 0.5 আসবে।'},
          {'title': 'sin, cos, tan', 'desc': 'ত্রিকোণমিতিক কোণ নির্ণয়ের জন্য ব্যবহার করুন। বাটনে চাপ দিলে ব্র্যাকেটসহ ফাংশন (যেমন: sin() আসবে।'},
          {'title': '^ (Power)', 'desc': 'কোনো সংখ্যার পাওয়ার বা ঘাত দিতে ব্যবহার করুন। যেমন: 2^3 = 8।'},
          {'title': 'ln', 'desc': 'ভিত্তি e বিশিষ্ট ন্যাচারাল লগারিদম (যেমন: ln(e) = 1) হিসাবের জন্য।'},
          {'title': 'log', 'desc': 'ভিত্তি 10 বিশিষ্ট সাধারণ লগারিদম (যেমন: log(100) = 2) হিসাবের জন্য।'},
          {'title': '√ (Square Root)', 'desc': 'যেকোনো সংখ্যার বর্গমূল বা রুট বের করতে ব্যবহার করুন (যেমন: √(16) = 4)।'},
          {'title': '( ) (ব্র্যাকেট)', 'desc': 'হিসাবের অগ্রাধিকার ঠিক করতে ও জটিল সমীকরণ সাজাতে বন্ধনী ব্যবহার করুন।'},
          {'title': 'π এবং e', 'desc': 'পাই (≈ ৩.১৪১৫৯) এবং অয়লার ধ্রুবক (≈ ২.৭১৮২৮) সরাসরি ইনপুটের জন্য ব্যবহার করুন।'},
          {'title': '! (Factorial)', 'desc': 'ধারাবাহিক গুণফল বের করতে ব্যবহার করুন (যেমন: 5! = 120)।'},
          {'title': '% (Percentage)', 'desc': 'শতকরা মান বের করার জন্য (যেমন: 50% = 0.5)।'},
          {'title': '+/-', 'desc': 'কোনো সংখ্যার আগে মাইনাস (-) বা প্লাস (+) চিহ্ন পরিবর্তন করতে ব্যবহার করুন।'},
          {'title': '⌫ (ব্যাকস্পেস বাটন)', 'desc': 'ইনপুট স্ক্রিনের বাম পাশে থাকা এই বাটনটি দিয়ে সমীকরণের টাইপ করা অক্ষরগুলো একটি একটি করে কেটে ফেলা বা মোছা যাবে।'},
        ] : [
          {'title': 'DEG / RAD', 'desc': 'Toggle angle unit between Degree (DEG) and Radian (RAD). In DEG mode, sin(30) = 0.5.'},
          {'title': 'sin, cos, tan', 'desc': 'Trigonometric functions. Pressing these inserts the function with parenthesis, e.g., sin().'},
          {'title': '^ (Power)', 'desc': 'Raises a number to the power of another. Example: 2^3 = 8.'},
          {'title': 'ln', 'desc': 'Natural logarithm base e (e.g., ln(e) = 1).'},
          {'title': 'log', 'desc': 'Common logarithm base 10 (e.g., log(100) = 2).'},
          {'title': '√ (Square Root)', 'desc': 'Calculates the square root of a number (e.g., √(16) = 4).'},
          {'title': '( ) (Parentheses)', 'desc': 'Used to define calculation precedence and group expressions.'},
          {'title': 'π and e', 'desc': 'Inserts math constants Pi (≈ 3.14159) and Euler\'s number (≈ 2.71828).'},
          {'title': '! (Factorial)', 'desc': 'Calculates product of all positive integers up to that number (e.g., 5! = 120).'},
          {'title': '% (Percentage)', 'desc': 'Converts value to a percentage (e.g., 50% = 0.5).'},
          {'title': '+/-', 'desc': 'Toggles the positive or negative sign of the current number segment.'},
          {'title': '⌫ (Backspace)', 'desc': 'Located on the left side of the input screen. Tap to delete equation characters one by one.'},
        ];

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.help_outline_rounded, color: const Color(0xFF3F51B5), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: guideItems.length,
                  itemBuilder: (context, index) {
                    final item = guideItems[index];
                    return _buildGuidelineItem(item['title']!, item['desc']!, isDark);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidelineItem(String title, String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9F0A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          const Divider(height: 16, color: Colors.white10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(trx('Calculator', 'ক্যালকুলেটর'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isStandard)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => _showScientificGuideline(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // Display Area
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    alignment: Alignment.bottomRight,
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_equation.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.backspace_outlined, color: Colors.white54, size: 20),
                                  onPressed: () => _buttonPressed("⌫"),
                                )
                              else
                                const SizedBox.shrink(),
                              Expanded(
                                child: Text(
                                  _equation.isEmpty ? "0" : _equation, 
                                  style: const TextStyle(fontSize: 32, color: Colors.white54, fontFamily: 'monospace'),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _result, 
                              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: Colors.white, fontFamily: 'monospace'),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Mode Toggle Tab
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildModeTab("Standard", _isStandard)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModeTab("Scientific", !_isStandard)),
                    ],
                  ),
                ),

            if (!_isStandard) ...[
              // Scientific Keys Row 1
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _buildScientificButton(_isDegree ? 'DEG' : 'RAD', isToggle: true),
                    _buildScientificButton('sin'),
                    _buildScientificButton('cos'),
                    _buildScientificButton('tan'),
                    _buildScientificButton('^'),
                  ],
                ),
              ),
              // Scientific Keys Row 2
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _buildScientificButton('ln'),
                    _buildScientificButton('log'),
                    _buildScientificButton('√'),
                    _buildScientificButton('('),
                    _buildScientificButton(')'),
                  ],
                ),
              ),
              // Scientific Keys Row 3
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _buildScientificButton('π'),
                    _buildScientificButton('e'),
                    _buildScientificButton('!'),
                    _buildScientificButton('%'),
                    _buildScientificButton('+/-'),
                  ],
                ),
              ),
            ],
            
            // Standard/Numeric Keypad
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Column(
                children: [
                  Row(children: [
                    _buildButton('AC'),
                    _buildButton('+/-'),
                    _buildButton('%'),
                    _buildButton('÷'),
                  ]),
                  Row(children: [
                    _buildButton('7'),
                    _buildButton('8'),
                    _buildButton('9'),
                    _buildButton('×'),
                  ]),
                  Row(children: [
                    _buildButton('4'),
                    _buildButton('5'),
                    _buildButton('6'),
                    _buildButton('-'),
                  ]),
                  Row(children: [
                    _buildButton('1'),
                    _buildButton('2'),
                    _buildButton('3'),
                    _buildButton('+'),
                  ]),
                  Row(children: [
                    _buildButton('0', flex: 2),
                    _buildButton('.'),
                    _buildButton('='),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class MathParser {
  final String expression;
  final bool isDegree;
  int _pos = -1;
  int _ch = 0;

  MathParser(this.expression, {this.isDegree = true});

  void _nextChar() {
    _pos++;
    _ch = (_pos < expression.length) ? expression.codeUnitAt(_pos) : -1;
  }

  bool _eat(int charToEat) {
    while (_ch == 32) {
      _nextChar();
    }
    if (_ch == charToEat) {
      _nextChar();
      return true;
    }
    return false;
  }

  double parse() {
    _nextChar();
    double x = _parseExpression();
    if (_pos < expression.length) throw Exception();
    return x;
  }

  double _parseExpression() {
    double x = _parseTerm();
    for (;;) {
      if (_eat(43)) {
        x += _parseTerm();
      } else if (_eat(45)) {
        x -= _parseTerm();
      } else {
        return x;
      }
    }
  }

  double _parseTerm() {
    double x = _parseFactor();
    for (;;) {
      if (_eat(42)) {
        x *= _parseFactor();
      } else if (_eat(47)) {
        x /= _parseFactor();
      } else {
        return x;
      }
    }
  }

  double _parseFactor() {
    if (_eat(43)) return _parseFactor();
    if (_eat(45)) return -_parseFactor();

    double x;
    int startPos = _pos;
    if (_eat(40)) {
      x = _parseExpression();
      _eat(41);
    } else if ((_ch >= 48 && _ch <= 57) || _ch == 46) {
      while ((_ch >= 48 && _ch <= 57) || _ch == 46) {
        _nextChar();
      }
      x = double.parse(expression.substring(startPos, _pos));
    } else if ((_ch >= 97 && _ch <= 122) || _ch == 960 || _ch == 8730) {
      if (_ch == 960) {
        _nextChar();
        x = math.pi;
      } else if (_ch == 101 && (_pos + 1 >= expression.length || expression.codeUnitAt(_pos + 1) < 97 || expression.codeUnitAt(_pos + 1) > 122)) {
        _nextChar();
        x = math.e;
      } else if (_ch == 8730) {
        _nextChar();
        x = math.sqrt(_parseFactor());
      } else {
        while (_ch >= 97 && _ch <= 122) {
          _nextChar();
        }
        String func = expression.substring(startPos, _pos);
        double arg = _parseFactor();
        if (func == "sin") {
          x = math.sin(isDegree ? arg * math.pi / 180 : arg);
        } else if (func == "cos") {
          x = math.cos(isDegree ? arg * math.pi / 180 : arg);
        } else if (func == "tan") {
          x = math.tan(isDegree ? arg * math.pi / 180 : arg);
        } else if (func == "log") {
          x = math.log(arg) / math.ln10;
        } else if (func == "ln") {
          x = math.log(arg);
        } else if (func == "sqrt") {
          x = math.sqrt(arg);
        } else {
          throw Exception();
        }
      }
    } else {
      throw Exception();
    }

    for (;;) {
      if (_eat(94)) {
        x = math.pow(x, _parseFactor()).toDouble();
      } else if (_eat(37)) {
        x = x / 100.0;
      } else if (_eat(33)) {
        x = _factorial(x);
      } else {
        return x;
      }
    }
  }

  double _factorial(double val) {
    if (val < 0) return double.nan;
    int n = val.toInt();
    if (n.toDouble() != val) return double.nan;
    double result = 1.0;
    for (int i = 1; i <= n; i++) {
      result *= i;
    }
    return result;
  }
}

