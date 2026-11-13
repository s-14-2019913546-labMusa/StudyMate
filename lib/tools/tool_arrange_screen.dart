import 'dart:convert';
import 'package:flutter/material.dart';
import '../language_manager.dart';

/// ব্যবহারকারীর সাজানো একটা ভাগ: ভাগের নাম + তার টুলগুলোর action, ক্রম অনুযায়ী
class ToolSection {
  final String name;
  final List<String> actions;
  ToolSection(this.name, this.actions);

  Map<String, dynamic> toJson() => {'name': name, 'tools': actions};
}

String encodeToolLayout(List<ToolSection> l) => jsonEncode(l.map((s) => s.toJson()).toList());

List<ToolSection>? decodeToolLayout(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return (jsonDecode(raw) as List)
        .map((e) => ToolSection((e['name'] ?? '').toString(), List<String>.from((e['tools'] as List).map((x) => x.toString()))))
        .toList();
  } catch (_) {
    return null;
  }
}

/// অ্যাপের ডিফল্ট ভাগ/টুলের উপর ব্যবহারকারীর ক্রম বসানো।
/// নতুন টুল (যা সাজানোর সময় ছিল না) নিজের ডিফল্ট ভাগের শেষে যোগ হয়; মুছে যাওয়া টুল বাদ যায়।
List<Map<String, dynamic>> applyToolLayout(List<Map<String, dynamic>> defaults, List<ToolSection>? layout) {
  if (layout == null || layout.isEmpty) return defaults;
  final catByName = {for (final c in defaults) c['name'] as String: c};
  final toolByAction = <String, Map<String, dynamic>>{};
  final homeCat = <String, String>{};
  for (final c in defaults) {
    for (final t in (c['tools'] as List<Map<String, dynamic>>)) {
      toolByAction[t['action'] as String] = t;
      homeCat[t['action'] as String] = c['name'] as String;
    }
  }
  final used = <String>{};
  final out = <Map<String, dynamic>>[];
  final outByName = <String, List<Map<String, dynamic>>>{};
  for (final s in layout) {
    final c = catByName[s.name];
    if (c == null || outByName.containsKey(s.name)) continue;
    final tools = <Map<String, dynamic>>[
      for (final a in s.actions)
        if (toolByAction.containsKey(a) && used.add(a)) toolByAction[a]!
    ];
    outByName[s.name] = tools;
    out.add({...c, 'tools': tools});
  }
  for (final c in defaults) {
    final name = c['name'] as String;
    if (!outByName.containsKey(name)) {
      final tools = <Map<String, dynamic>>[];
      outByName[name] = tools;
      out.add({...c, 'tools': tools});
    }
  }
  for (final a in toolByAction.keys) {
    if (!used.contains(a)) outByName[homeCat[a]]!.add(toolByAction[a]!);
  }
  return out;
}

class ToolArrangeResult {
  final List<ToolSection> layout;
  final bool reset;
  ToolArrangeResult(this.layout, {this.reset = false});
}

/// টুল আগে-পরে সাজানোর পাতা। টুল টেনে অন্য ভাগেও নেওয়া যায়, ভাগগুলো ↑↓ দিয়ে সরানো যায়।
class ToolArrangeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  const ToolArrangeScreen({super.key, required this.categories});

  @override
  State<ToolArrangeScreen> createState() => _ToolArrangeScreenState();
}

class _ToolArrangeScreenState extends State<ToolArrangeScreen> {
  late final Map<String, Map<String, dynamic>> _cats = {for (final c in widget.categories) c['name'] as String: c};
  late final Map<String, Map<String, dynamic>> _tools = {
    for (final c in widget.categories)
      for (final t in (c['tools'] as List<Map<String, dynamic>>)) t['action'] as String: t,
  };
  late List<ToolSection> _sections = [
    for (final c in widget.categories)
      ToolSection(c['name'] as String, [for (final t in (c['tools'] as List<Map<String, dynamic>>)) t['action'] as String])
  ];
  bool _changed = false;

  // সমতল তালিকা: 'h:<ভাগ>' বা 't:<action>'
  List<String> get _flat => [
        for (final s in _sections) ...['h:${s.name}', for (final a in s.actions) 't:$a']
      ];

  void _rebuildFrom(List<String> flat) {
    final out = <ToolSection>[];
    for (final k in flat) {
      if (k.startsWith('h:')) {
        out.add(ToolSection(k.substring(2), []));
      } else {
        out.last.actions.add(k.substring(2));
      }
    }
    _sections = out;
  }

  void _onReorder(int oldIndex, int newIndex) {
    final flat = _flat;
    final item = flat.removeAt(oldIndex);
    if (newIndex < 1) newIndex = 1; // প্রথম ভাগের শিরোনামের উপরে টুল রাখা যাবে না
    flat.insert(newIndex.clamp(1, flat.length), item);
    setState(() {
      _rebuildFrom(flat);
      _changed = true;
    });
  }

  void _moveSection(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _sections.length) return;
    setState(() {
      final s = _sections.removeAt(i);
      _sections.insert(j, s);
      _changed = true;
    });
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(trx('Restore the app order?', 'অ্যাপের আগের ক্রমে ফিরবেন?')),
        content: Text(trx('Your own arrangement will be removed.', 'আপনার নিজের সাজানো ক্রম মুছে যাবে।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(trx('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(trx('Restore', 'ফিরিয়ে আনুন'))),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, ToolArrangeResult(const [], reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flat = _flat;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        // ফিরে গেলেই সাজানো ক্রম সেভ হয়
        if (!didPop) Navigator.pop(context, ToolArrangeResult(_sections));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(trx('Arrange tools', 'টুল সাজান')),
          actions: [
            TextButton(onPressed: _reset, child: Text(trx('Default', 'আগের মতো'))),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trx('Hold ≡ and drag a tool up or down — even into another section. Use ↑ ↓ to move a whole section. Changes are saved when you go back.',
                    '≡ চিহ্ন ধরে টুল উপরে-নিচে টানুন, চাইলে অন্য ভাগেও নিতে পারবেন। পুরো ভাগ সরাতে ↑ ↓ চাপুন। ফিরে গেলেই সেভ হয়ে যাবে।'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                itemCount: flat.length,
                onReorderItem: _onReorder,
                itemBuilder: (context, i) {
                  final k = flat[i];
                  if (k.startsWith('h:')) {
                    final name = k.substring(2);
                    final si = _sections.indexWhere((s) => s.name == name);
                    final c = _cats[name];
                    return Padding(
                      key: ValueKey(k),
                      padding: EdgeInsets.only(top: i == 0 ? 4 : 18, bottom: 4),
                      child: Row(children: [
                        Icon(c?['icon'] as IconData? ?? Icons.folder_rounded, size: 20, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          tooltip: trx('Move section up', 'ভাগ উপরে নিন'),
                          icon: const Icon(Icons.arrow_upward_rounded),
                          onPressed: si > 0 ? () => _moveSection(si, -1) : null,
                        ),
                        IconButton(
                          tooltip: trx('Move section down', 'ভাগ নিচে নিন'),
                          icon: const Icon(Icons.arrow_downward_rounded),
                          onPressed: si < _sections.length - 1 ? () => _moveSection(si, 1) : null,
                        ),
                      ]),
                    );
                  }
                  final t = _tools[k.substring(2)]!;
                  final color = t['color'] as Color;
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(k),
                    index: i,
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(t['icon'] as IconData, color: color, size: 20),
                        ),
                        title: Text((t['title'] as String).tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
