import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/tools/tool_arrange_screen.dart';

void main() {
  List<Map<String, dynamic>> defaults() => [
        {
          'name': 'A',
          'tools': <Map<String, dynamic>>[
            {'action': 'a1'},
            {'action': 'a2'},
            {'action': 'new_tool'},
          ]
        },
        {
          'name': 'B',
          'tools': <Map<String, dynamic>>[
            {'action': 'b1'},
          ]
        },
      ];

  List<List<String>> shape(List<Map<String, dynamic>> c) =>
      [for (final s in c) [s['name'] as String, for (final t in s['tools'] as List) t['action'] as String]];

  test('no saved layout keeps the app order', () {
    expect(shape(applyToolLayout(defaults(), null)), [
      ['A', 'a1', 'a2', 'new_tool'],
      ['B', 'b1'],
    ]);
  });

  test('saved order, moved tool, new tool appended, removed tool dropped', () {
    final saved = decodeToolLayout(encodeToolLayout([
      ToolSection('B', ['b1', 'a2', 'gone']),
      ToolSection('A', ['a1']),
    ]));
    expect(shape(applyToolLayout(defaults(), saved)), [
      ['B', 'b1', 'a2'],
      ['A', 'a1', 'new_tool'],
    ]);
  });

  test('broken saved data is ignored', () {
    expect(decodeToolLayout('not json'), isNull);
  });
}
