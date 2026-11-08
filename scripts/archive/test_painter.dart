import 'package:flutter/material.dart';

void main() {
  final painter = TextPainter(textDirection: TextDirection.ltr);
  painter.text = const TextSpan(text: "Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World Hello World", style: TextStyle(fontSize: 18, height: 1.55));
  painter.layout(maxWidth: 200);
  print(painter.size);
}
