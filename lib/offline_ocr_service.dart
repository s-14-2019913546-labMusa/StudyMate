import 'dart:io';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:http/http.dart' as http;

/// বিনা খরচে, ফোনের ভেতরেই ছবি থেকে লেখা পড়া (Tesseract, ওপেন সোর্স)।
/// বাংলা ও ইংরেজির ভাষা-ফাইল প্রথমবার একবার ডাউনলোড হয় (~৫ MB), তারপর ইন্টারনেট ছাড়াই চলে।
/// কোনো API key বা টাকা লাগে না।
class OfflineOcrService {
  static const _langs = ['ben', 'eng'];
  // Tesseract প্রকল্পের অফিসিয়াল ছোট (fast) ভাষা-ফাইল
  static const _base = 'https://github.com/tesseract-ocr/tessdata_fast/raw/main';

  static Future<String> _dir() async => FlutterTesseractOcr.getTessdataPath();

  static Future<bool> isReady() async {
    final dir = await _dir();
    for (final l in _langs) {
      final f = File('$dir/$l.traineddata');
      if (!await f.exists() || await f.length() < 100000) return false;
    }
    return true;
  }

  /// ভাষা-ফাইল না থাকলে ডাউনলোড করে। [onProgress] ০.০–১.০
  static Future<void> ensureLanguageData({void Function(double)? onProgress}) async {
    final dir = await _dir();
    await Directory(dir).create(recursive: true);
    for (int i = 0; i < _langs.length; i++) {
      final l = _langs[i];
      final f = File('$dir/$l.traineddata');
      if (await f.exists() && await f.length() > 100000) continue;
      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse('$_base/$l.traineddata'));
        final res = await client.send(req).timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        final total = res.contentLength ?? 0;
        final tmp = File('${f.path}.part');
        final sink = tmp.openWrite();
        var got = 0;
        await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call((i + got / total) / _langs.length);
        }
        await sink.close();
        await tmp.rename(f.path);
      } finally {
        client.close();
      }
    }
    onProgress?.call(1);
  }

  /// ছবির ফাইল থেকে লেখা (বাংলা + ইংরেজি)
  static Future<String> readImage(String imagePath) async {
    await ensureLanguageData();
    final text = await FlutterTesseractOcr.extractText(
      imagePath,
      language: 'ben+eng',
      args: {'preserve_interword_spaces': '1', 'psm': '3'},
    ).timeout(const Duration(seconds: 90));
    // অতিরিক্ত ফাঁকা লাইন ছেঁটে ফেলা
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
