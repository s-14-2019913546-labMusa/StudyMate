import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ai_service.dart';
import 'deck_dashboard_screen.dart';
import 'language_manager.dart';
import 'mcq/mcq_service.dart';
import 'mcq/mcq_test_screen.dart';
import 'tools/quick_notes_screen.dart';

/// বইয়ের পাতা বা খাতার ছবি তুলুন → লেখা বের হবে (বাংলা/ইংরেজি) →
/// নোট হিসেবে রাখুন, MCQ বানান বা ফ্ল্যাশকার্ড বানান।
class PhotoToNoteScreen extends StatefulWidget {
  const PhotoToNoteScreen({super.key});

  @override
  State<PhotoToNoteScreen> createState() => _PhotoToNoteScreenState();
}

class _PhotoToNoteScreenState extends State<PhotoToNoteScreen> {
  final _picker = ImagePicker();
  final _text = TextEditingController();
  final _title = TextEditingController();
  Uint8List? _image;
  String _mime = 'image/jpeg';
  bool _reading = false;
  bool _working = false;

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<String?> _apiKey() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final key = uid == null ? null : await AIService.getSavedApiKey(uid);
    if (key == null || key.isEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(trx('Gemini API key needed', 'Gemini API Key দরকার')),
            content: Text(trx(
              'Reading photos uses Google Gemini. Add your free API key in Profile → AI Settings (Gemini API Key), then try again.',
              'ছবি থেকে লেখা পড়তে Google Gemini লাগে। Profile → AI Settings (Gemini API Key)-এ আপনার ফ্রি কী দিন, তারপর আবার চেষ্টা করুন।',
            )),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'.tr()))],
          ),
        );
      }
      return null;
    }
    return key;
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      setState(() {
        _image = bytes;
        _mime = name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        _text.clear();
      });
      await _read();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not open the photo: $e', 'ছবি খোলা যায়নি: $e'))));
      }
    }
  }

  Future<void> _read() async {
    final img = _image;
    if (img == null) return;
    final key = await _apiKey();
    if (key == null) return;
    setState(() => _reading = true);
    try {
      final text = await AIService.extractTextFromImage(img, _mime, key);
      if (!mounted) return;
      setState(() => _text.text = text);
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(trx('No text found in this photo. Try a clearer, closer photo.', 'ছবিতে কোনো লেখা পাওয়া যায়নি। আরও কাছ থেকে পরিষ্কার ছবি তুলুন।'))));
      } else if (_title.text.isEmpty) {
        final firstLine = text.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').replaceAll('#', '').trim();
        _title.text = firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not read the photo: $e', 'ছবি পড়া যায়নি: $e'))));
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _openAsNote() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickNotesScreen(
          initialTitle: _title.text.trim().isEmpty ? trx('Photo note', 'ছবির নোট') : _title.text.trim(),
          initialContent: t,
        ),
      ),
    );
  }

  Future<void> _makeMcq() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    final key = await _apiKey();
    if (key == null) return;
    setState(() => _working = true);
    try {
      final raw = await AIService.generateMcqs(topicOrText: t, apiKey: key, count: 10, fromText: true);
      final subject = _title.text.trim().isEmpty ? trx('Photo notes', 'ছবির নোট') : _title.text.trim();
      final qs = raw
          .map((m) => McqQuestion(
                id: McqQuestion.stableId('ai', m['question'] as String),
                subject: subject,
                question: m['question'] as String,
                options: List<String>.from(m['options'] as List),
                answer: m['answer'] as int,
                explanation: (m['explanation'] ?? '') as String,
                source: 'ai',
              ))
          .toList();
      if (!mounted) return;
      if (qs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not make questions from this text.', 'এই লেখা থেকে প্রশ্ন বানানো গেল না।'))));
        return;
      }
      await McqService.saveCustom(qs);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => McqTestScreen(questions: qs, mode: 'practice')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error: $e', 'সমস্যা: $e'))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _makeFlashcards() async {
    final t = _text.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (t.isEmpty || user == null) return;
    final key = await _apiKey();
    if (key == null) return;
    setState(() => _working = true);
    try {
      final cards = await AIService.generateQuizFromNote(t, key);
      if (!mounted) return;
      if (cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Could not make cards from this text.', 'এই লেখা থেকে কার্ড বানানো গেল না।'))));
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final list = [
        for (int i = 0; i < cards.length; i++) {'id': '$now$i', 'front': cards[i]['front'], 'back': cards[i]['back'], 'difficulty': 'medium'},
      ];
      final title = _title.text.trim().isEmpty ? trx('Photo cards', 'ছবির কার্ড') : _title.text.trim();
      final ref = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('flashcard_decks').add({
        'title': title.length > 30 ? title.substring(0, 30) : title,
        'description': trx('Made from a photo', 'ছবি থেকে বানানো'),
        'cards': list,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => DeckDashboardScreen(deckId: ref.id, deckTitle: title, allCards: list)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trx('Error: $e', 'সমস্যা: $e'))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _text.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(trx('Photo to Note', 'ছবি থেকে নোট'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_image == null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.document_scanner_rounded, size: 56, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(trx('Take a photo of a book page or your notebook', 'বইয়ের পাতা বা খাতার ছবি তুলুন'),
                      textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    trx('The text (Bengali or English) is typed out for you. Then save it as a note, or turn it into MCQs or flashcards.',
                        'লেখাটা (বাংলা বা ইংরেজি) টাইপ হয়ে আসবে। তারপর নোট হিসেবে রাখুন, অথবা MCQ বা ফ্ল্যাশকার্ড বানান।'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_image!, height: 220, fit: BoxFit.cover, width: double.infinity),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _reading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(trx('Camera', 'ক্যামেরা')),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(trx('Gallery', 'গ্যালারি')),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                ),
              ),
            ],
          ),
          if (_reading) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(trx('Reading the photo…', 'ছবি থেকে লেখা পড়া হচ্ছে…'), textAlign: TextAlign.center),
          ],
          if (hasText || (_image != null && !_reading)) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: trx('Title', 'শিরোনাম'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 20,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: trx('Text (you can fix mistakes here)', 'লেখা (ভুল থাকলে এখানে ঠিক করুন)'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasText && !_working ? _openAsNote : null,
              icon: const Icon(Icons.note_add_rounded),
              label: Text(trx('Open as a note', 'নোট হিসেবে খুলুন')),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasText && !_working ? _makeMcq : null,
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(trx('Make MCQs', 'MCQ বানান')),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasText && !_working ? _makeFlashcards : null,
                    icon: const Icon(Icons.style_rounded),
                    label: Text(trx('Flashcards', 'ফ্ল্যাশকার্ড')),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  ),
                ),
              ],
            ),
            if (_working) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (_image != null && !hasText && !_reading)
              TextButton.icon(onPressed: _read, icon: const Icon(Icons.refresh_rounded), label: Text(trx('Read again', 'আবার পড়ুন'))),
          ],
        ],
      ),
    );
  }
}
