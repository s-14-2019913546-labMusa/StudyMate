import 'package:flutter/material.dart';

/// প্রথমবার খুললে শুধু "No data" না দেখিয়ে কী করা যায় তা দেখায়:
/// আইকন, শিরোনাম, ছোট ব্যাখ্যা, একটা উদাহরণ কার্ড আর "প্রথমটা বানান" বাটন।
class EmptyStateGuide extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final String message;

  /// উদাহরণের শিরোনাম (যেমন "উদাহরণ") ও কয়েকটা লাইন
  final String? exampleTitle;
  final List<String> exampleLines;

  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const EmptyStateGuide({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.color,
    this.exampleTitle,
    this.exampleLines = const [],
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: c),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            if (exampleLines.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exampleTitle != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 16, color: c),
                            const SizedBox(width: 6),
                            Text(exampleTitle!, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13)),
                          ],
                        ),
                      ),
                    for (final line in exampleLines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6, right: 8),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                              ),
                            ),
                            Expanded(child: Text(line, style: const TextStyle(fontSize: 13, height: 1.4))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: c,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
