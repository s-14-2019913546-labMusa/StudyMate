import 'package:flutter/material.dart';
import '../language_manager.dart';

/// কিছু মোছার পরে "Undo" বাটনসহ বার্তা দেখায়।
/// মোছার আগেই `ScaffoldMessenger.of(context)` নিয়ে রাখুন, কারণ মোছার পরে
/// কার্ড/উইজেটটা স্ক্রিন থেকে চলে যেতে পারে।
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message,
  Future<void> Function() onUndo,
) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: trx('UNDO', 'ফিরিয়ে আনুন'),
        onPressed: () async {
          try {
            await onUndo();
            messenger.showSnackBar(
              SnackBar(
                content: Text(trx('Restored ✓', 'ফিরিয়ে আনা হয়েছে ✓')),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (e) {
            debugPrint('Undo failed: $e');
            messenger.showSnackBar(
              SnackBar(
                content: Text(trx('Could not restore. Please try again.', 'ফিরিয়ে আনা যায়নি। আবার চেষ্টা করুন।')),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    ),
  );
}
