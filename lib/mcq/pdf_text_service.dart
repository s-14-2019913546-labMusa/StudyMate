import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../offline_ocr_service.dart';

/// PDF থেকে লেখা বের করা, পুরোটাই ফোনে এবং ফ্রিতে।
/// - যে পাতায় লেখা আছে (টাইপ করা PDF) সেখান থেকে সরাসরি লেখা তোলা হয় (pdfrx / PDFium)।
/// - যে পাতা শুধু ছবি (ক্যামস্ক্যানার, স্ক্যান) সেটা ছবি বানিয়ে অফলাইন Tesseract OCR দিয়ে পড়া হয়।
class PdfTextService {
  static Future<void> _init() => pdfrxFlutterInitialize();

  static Future<int> pageCount(String path) async {
    await _init();
    final doc = await PdfDocument.openFile(path);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  // ক্যামস্ক্যানারের জলছাপ ইত্যাদি বাদ দিয়ে আসল লেখা কতটুকু
  static int _meaningful(String t) => t
      .replaceAll(RegExp(r'scanned\s+(with|by)\s+\w+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s'), '')
      .length;

  /// [from]–[to] পাতা (১ থেকে গোনা) পড়ে সব লেখা জোড়া দিয়ে ফেরত দেয়।
  /// [onProgress]: (কত পাতা হলো, মোট, এই পাতায় OCR লাগল কিনা)
  /// [forceOcr]: লেখা থাকলেও OCR করা (লেখা ভাঙাচোরা এলে)
  static Future<({String text, int ocrPages, int textPages})> extract(
    String path, {
    required int from,
    required int to,
    bool forceOcr = false,
    void Function(int done, int total, bool ocr)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await _init();
    final doc = await PdfDocument.openFile(path);
    final buf = StringBuffer();
    var ocrPages = 0, textPages = 0;
    final total = to - from + 1;
    final tmpDir = await getTemporaryDirectory();
    try {
      for (var p = from; p <= to; p++) {
        if (isCancelled?.call() ?? false) break;
        final page = doc.pages[p - 1];
        String text = '';
        if (!forceOcr) {
          try {
            text = (await page.loadText())?.fullText ?? '';
          } catch (_) {}
        }
        var usedOcr = false;
        if (forceOcr || _meaningful(text) < 40) {
          usedOcr = true;
          onProgress?.call(p - from, total, true);
          final file = File('${tmpDir.path}/pdf_ocr_page.png');
          if (await _renderPage(page, file)) {
            try {
              text = await OfflineOcrService.readImage(file.path);
            } finally {
              try {
                await file.delete();
              } catch (_) {}
            }
          }
          ocrPages++;
        } else {
          textPages++;
        }
        buf.writeln(text);
        buf.writeln();
        onProgress?.call(p - from + 1, total, usedOcr);
      }
    } finally {
      await doc.dispose();
    }
    return (text: buf.toString(), ocrPages: ocrPages, textPages: textPages);
  }

  /// পাতাটাকে OCR-এর জন্য ~২০০ dpi ধূসর ছবিতে রূপান্তর
  static Future<bool> _renderPage(PdfPage page, File out) async {
    // A4 পাতা ৭২ dpi-তে ~৫৯৫ px চওড়া; ১৭০০ px চওড়া মানে ~২০০ dpi, ফোনের মেমোরিতেও আরামে আঁটে
    final scale = (1700 / page.width).clamp(1.0, 4.0);
    final w = (page.width * scale).round(), h = (page.height * scale).round();
    final image = await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xffffffff);
    if (image == null) return false;
    try {
      final png = await compute(_encodeGrayPng, (image.pixels, image.width, image.height));
      await out.writeAsBytes(png, flush: true);
      return true;
    } finally {
      image.dispose();
    }
  }
}

Uint8List _encodeGrayPng((Uint8List, int, int) a) {
  final (pixels, w, h) = a;
  final im = img.Image.fromBytes(width: w, height: h, bytes: pixels.buffer, bytesOffset: pixels.offsetInBytes, numChannels: 4, order: img.ChannelOrder.bgra);
  return img.encodePng(img.grayscale(im), level: 1);
}
