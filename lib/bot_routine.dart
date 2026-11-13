part of 'bot_chat_screen.dart';

/// বটের রুটিন সহকারী: "এখন কী পড়ব", টাস্ক যোগ/সরানো/পিছানো/মোছা, কালকের প্ল্যান।
/// সব অফলাইন নিয়মে চলে; ডেটা লেখা হয় [RoutineAssistant] দিয়ে।
extension _RoutineBot on _BotChatScreenState {
  // ---------------- ছোট সহায়ক ----------------
  bool get _bn => LanguageManager().isBengali;
  String _d(String s) => _bn ? LanguageManager.toBnDigits(s) : s;

  String _clock(DateTime t) {
    if (!_bn) return DateFormat('h:mm a').format(t);
    final h = t.hour;
    final period = h < 5 ? 'রাত' : h < 12 ? 'সকাল' : h < 15 ? 'দুপুর' : h < 18 ? 'বিকাল' : h < 20 ? 'সন্ধ্যা' : 'রাত';
    return '$period ${_d(DateFormat('h:mm').format(t))}';
  }

  String _range(Task t) {
    if (t.startTime == null) return trx('no time set', 'সময় নেই');
    final e = t.endTime ?? t.startTime!.add(Duration(minutes: t.totalDurationMinutes > 0 ? t.totalDurationMinutes : 60));
    return '${_clock(t.startTime!)} – ${_clock(e)}';
  }

  String _dayLabel(DateTime d) {
    final today = RoutineAssistant.dayOf(DateTime.now());
    final diff = RoutineAssistant.dayOf(d).difference(today).inDays;
    if (diff == 0) return trx('today', 'আজ');
    if (diff == 1) return trx('tomorrow', 'কাল');
    if (diff == 2) return trx('day after tomorrow', 'পরশু');
    return _d(DateFormat('d MMM').format(d));
  }

  String _name(Task t) => t.title.replaceAll('[WR]', '').trim();
  String _mins(int m) {
    if (m >= 60 && m % 60 == 0) return _d(trx('${m ~/ 60} h', '${m ~/ 60} ঘণ্টা'));
    if (m > 60) return _d(trx('${m ~/ 60} h ${m % 60} min', '${m ~/ 60} ঘণ্টা ${m % 60} মিনিট'));
    return _d(trx('$m min', '$m মিনিট'));
  }

  Map<String, dynamic> _act(String label, String type, [Map<String, dynamic> data = const {}]) =>
      {'label': label, 'type': type, 'data': data};
  Map<String, dynamic> _taskData(DateTime day, Task t, [Map<String, dynamic> extra = const {}]) =>
      {'day': RoutineAssistant.dayOf(day).millisecondsSinceEpoch, 'task': RoutineAssistant.taskToJson(t), ...extra};

  List<Map<String, dynamic>> _taskButtons(DateTime day, Task t) {
    if (t.status == 'running') {
      return [_act(trx('✓ Done', '✓ শেষ করেছি'), 'complete', _taskData(day, t))];
    }
    return [
      _act(trx('▶ Start', '▶ শুরু করুন'), 'start', _taskData(day, t)),
      _act(trx('⏩ +15 min', '⏩ ১৫ মিনিট পিছাও'), 'postpone', _taskData(day, t, {'min': 15})),
      _act(trx('📅 Tomorrow', '📅 কালকে'), 'tomorrow', _taskData(day, t)),
    ];
  }

  String _overlapNote(List<Task> dayTasks, Task t) {
    if (t.startTime == null) return '';
    final o = RoutineIntentParser.overlaps(dayTasks, t.startTime!, t.endTime ?? t.startTime!.add(const Duration(hours: 1)), exceptId: t.id);
    if (o.isEmpty) return '';
    final names = o.map((x) => '${_name(x)} (${_range(x)})').join(', ');
    return '\n\n⚠️ ${trx('Clashes with', 'সময় মিলে যাচ্ছে')}: $names';
  }

  // ---------------- লেখা থেকে ----------------
  Future<void> _handleRoutineIntent(RoutineIntent i) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _botSay(trx('⚠️ Please log in to manage your routine.', '⚠️ রুটিন সামলাতে আগে লগইন করুন।'));
      return;
    }
    try {
      switch (i.type) {
        case RoutineIntentType.whatNow:
          await _rbWhatNow();
        case RoutineIntentType.planTomorrow:
          await _rbPlanTomorrow();
        case RoutineIntentType.moveUnfinished:
          await _rbMoveUnfinished();
        case RoutineIntentType.add:
          await _rbAdd(i.raw);
        default:
          await _rbTarget(i);
      }
    } catch (e) {
      _botSay(trx('⚠️ Could not update the routine: $e', '⚠️ রুটিন বদলানো গেল না: $e'));
    }
  }

  Future<void> _rbTarget(RoutineIntent i) async {
    final today = RoutineAssistant.dayOf(DateTime.now());
    final tasks = await RoutineAssistant.loadDay(today);
    List<Task> matches;
    if (i.query.isEmpty) {
      final (cur, next) = RoutineIntentParser.currentAndNext(tasks, DateTime.now());
      matches = [if (cur != null) cur else if (next != null) next];
    } else {
      matches = RoutineIntentParser.findTasks(tasks, i.query);
    }

    if (matches.isEmpty) {
      final q = i.query.isEmpty ? trx('a task', 'কোনো টাস্ক') : '"${i.query}"';
      _botSay(
        trx('🔍 I couldn\'t find $q in today\'s routine.', '🔍 আজকের রুটিনে $q পাইনি।'),
        actions: [
          if (i.type == RoutineIntentType.moveToTime) _act(trx('➕ Add as new task', '➕ নতুন টাস্ক হিসেবে যোগ'), 'add', {'raw': i.raw}),
          _act(trx('📋 Today\'s tasks', '📋 আজকের টাস্ক'), 'what_now'),
        ],
      );
      return;
    }
    if (matches.length > 1) {
      _botSay(
        trx('Which one?', 'কোনটার কথা বলছেন?'),
        actions: matches.take(5).map((t) {
          return _act('${_name(t)} · ${t.startTime != null ? _clock(t.startTime!) : ''}', 'pick',
              _taskData(today, t, {'intent': i.type.name, 'amount': i.amount, 'raw': i.raw}));
        }).toList(),
      );
      return;
    }
    await _rbApply(i.type, today, matches.first, amount: i.amount, raw: i.raw);
  }

  Future<void> _rbApply(RoutineIntentType type, DateTime day, Task t, {int amount = 0, String raw = ''}) async {
    switch (type) {
      case RoutineIntentType.delete:
        await RoutineAssistant.removeTask(day, t.id);
        _botSay(trx('🗑️ Removed **${_name(t)}** (${_range(t)}).', '🗑️ মুছে দিলাম: **${_name(t)}** (${_range(t)})।'),
            actions: [_act(trx('↩ Undo', '↩ ফেরত আনো'), 'undo', _taskData(day, t))]);
      case RoutineIntentType.postpone:
        final mins = amount > 0 ? amount : 15;
        final moved = await RoutineAssistant.postpone(day, t, mins);
        final dayTasks = await RoutineAssistant.loadDay(day);
        _botSay(
          trx('⏩ **${_name(t)}** moved by ${_mins(mins)}: now ${_range(moved)}.', '⏩ **${_name(t)}** ${_mins(mins)} পিছালাম: এখন ${_range(moved)}।') +
              _overlapNote(dayTasks, moved),
          actions: [_act(trx('↩ Undo', '↩ আগের সময়ে'), 'undo', _taskData(day, t))],
        );
      case RoutineIntentType.moveToDay:
        final days = amount > 0 ? amount : 1;
        final (moved, to) = await RoutineAssistant.moveToDay(day, t, days);
        _botSay(
          trx('📅 **${_name(t)}** moved to ${_dayLabel(to)}, ${_range(moved)}.', '📅 **${_name(t)}** ${_dayLabel(to)} নিয়ে গেলাম, ${_range(moved)}।'),
          actions: [_act(trx('↩ Undo', '↩ ফেরত আনো'), 'undo', _taskData(day, t, {'removeFrom': to.millisecondsSinceEpoch}))],
        );
      case RoutineIntentType.moveToTime:
        final p = QuickTaskParser.parse(raw);
        if (!p.timeFound) {
          _botSay(trx('⏰ Which time? e.g. "English at 9pm"', '⏰ কয়টায় সরাব? যেমন: "ইংরেজি রাত ৯টায় সরাও"'));
          return;
        }
        var targetDay = day;
        var task = t;
        if (p.dayOffset > 0) {
          final (m, to) = await RoutineAssistant.moveToDay(day, t, p.dayOffset);
          targetDay = to;
          task = m;
        }
        final start = DateTime(targetDay.year, targetDay.month, targetDay.day, p.start.hour, p.start.minute);
        final moved = await RoutineAssistant.moveToTime(targetDay, task, start);
        final dayTasks = await RoutineAssistant.loadDay(targetDay);
        _botSay(
          trx('🕘 **${_name(t)}** is now ${_dayLabel(targetDay)}, ${_range(moved)}.', '🕘 **${_name(t)}** এখন ${_dayLabel(targetDay)}, ${_range(moved)}।') +
              _overlapNote(dayTasks, moved),
          actions: [
            _act(trx('↩ Undo', '↩ আগের সময়ে'), 'undo',
                _taskData(day, t, {if (targetDay != day) 'removeFrom': targetDay.millisecondsSinceEpoch})),
          ],
        );
      default:
        break;
    }
  }

  Future<void> _rbAdd(String raw) async {
    final (task, day) = await RoutineAssistant.addFromText(raw);
    final dayTasks = await RoutineAssistant.loadDay(day);
    final p = QuickTaskParser.parse(raw);
    final guess = p.timeFound ? '' : trx('\n\n_No time given, so I picked ${_clock(task.startTime!)}._', '\n\n_সময় বলেননি, তাই ${_clock(task.startTime!)} ধরে নিলাম।_');
    _botSay(
      trx(
            '✅ Added **${_name(task)}**: ${_dayLabel(day)}, ${_range(task)} (${_mins(task.totalDurationMinutes)}).\n⏰ You\'ll get a reminder when it starts.',
            '✅ যোগ হলো **${_name(task)}**: ${_dayLabel(day)}, ${_range(task)} (${_mins(task.totalDurationMinutes)})।\n⏰ শুরুর সময় নোটিফিকেশন যাবে।',
          ) +
          guess +
          _overlapNote(dayTasks, task),
      actions: [
        _act(trx('↩ Cancel', '↩ বাতিল'), 'undo_add', {'day': day.millisecondsSinceEpoch, 'id': task.id}),
        _act(trx('🕘 Change time', '🕘 সময় বদলাই'), 'fill', {'text': trx('${_name(task)} at ', '${_name(task)} ') + trx('', 'টায় সরাও')}),
      ],
    );
  }

  // ---------------- এখন কী পড়ব ----------------
  Future<void> _rbWhatNow() async {
    final now = DateTime.now();
    final today = RoutineAssistant.dayOf(now);
    final tasks = await RoutineAssistant.loadDay(today);
    if (tasks.isEmpty) {
      _botSay(
        trx('📭 No tasks today yet. Tell me one, e.g. **"Math 7pm 2 hours"**.', '📭 আজ এখনো কোনো টাস্ক নেই। লিখে দিন, যেমন: **"সন্ধ্যা ৭টায় গণিত ২ ঘণ্টা"**।'),
        actions: [
          _act(trx('➕ Add a task', '➕ টাস্ক যোগ'), 'fill', {'text': trx('Math 7pm 2 hours', 'সন্ধ্যা ৭টায় গণিত ২ ঘণ্টা')}),
          _act(trx('🌙 Plan tomorrow', '🌙 কালকের প্ল্যান'), 'plan_tomorrow'),
        ],
      );
      return;
    }
    final (cur, next) = RoutineIntentParser.currentAndNext(tasks, now);
    final done = tasks.where((t) => t.isCompleted || t.status == 'completed').length;
    final missed = RoutineIntentParser.missed(tasks, now).where((t) => t.id != cur?.id).toList();
    final b = StringBuffer();
    final actions = <Map<String, dynamic>>[];

    if (cur != null) {
      final end = cur.endTime ?? cur.startTime!.add(const Duration(hours: 1));
      final left = end.difference(now).inMinutes;
      if (cur.status == 'running') {
        b.write(trx('▶ **Now: ${_name(cur)}** (${_range(cur)}), running — ${_mins(left)} left.', '▶ **এখন: ${_name(cur)}** (${_range(cur)}), চলছে — আর ${_mins(left)} বাকি।'));
      } else {
        b.write(trx('▶ **Now: ${_name(cur)}** (${_range(cur)}). It should have started at ${_clock(cur.startTime!)}.',
            '▶ **এখন: ${_name(cur)}** (${_range(cur)})। ${_clock(cur.startTime!)}-এ শুরু হওয়ার কথা।'));
      }
      actions.addAll(_taskButtons(today, cur));
    } else if (next != null) {
      final inMin = next.startTime!.difference(now).inMinutes;
      b.write(trx('☕ Free right now. Next: **${_name(next)}** at ${_clock(next.startTime!)} (in ${_mins(inMin)}).',
          '☕ এখন ফাঁকা। পরের টাস্ক **${_name(next)}**, ${_clock(next.startTime!)}-এ (${_mins(inMin)} পর)।'));
      actions.add(_act(trx('▶ Start it now', '▶ এখনই শুরু'), 'start', _taskData(today, next)));
    } else {
      b.write(trx('🎉 Nothing else is scheduled for today.', '🎉 আজ আর কোনো টাস্ক বাকি নেই।'));
      actions.add(_act(trx('🌙 Plan tomorrow', '🌙 কালকের প্ল্যান'), 'plan_tomorrow'));
    }
    if (cur != null && next != null) {
      b.write(trx('\n\nNext: **${_name(next)}** at ${_clock(next.startTime!)}.', '\n\nএর পরে: **${_name(next)}**, ${_clock(next.startTime!)}-এ।'));
    }
    if (missed.isNotEmpty) {
      b.write(trx('\n\n⚠️ Time passed but not done: ', '\n\n⚠️ সময় পেরিয়ে গেছে, হয়নি: '));
      b.write(missed.take(4).map(_name).join(', '));
      actions.add(_act(trx('📅 Move unfinished to tomorrow', '📅 বাকিগুলো কালকে (${_d('${missed.length}')})'), 'move_unfinished'));
    }
    b.write(_d(trx('\n\n📊 Today: $done/${tasks.length} done.', '\n\n📊 আজ: ${tasks.length}টার মধ্যে $doneটা শেষ।')));
    _botSay(b.toString(), actions: actions);
  }

  // ---------------- কালকের প্ল্যান ----------------
  Future<void> _rbPlanTomorrow() async {
    final today = RoutineAssistant.dayOf(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final todayTasks = await RoutineAssistant.loadDay(today);
    final tTasks = await RoutineAssistant.loadDay(tomorrow)
      ..sort((a, b) => (a.startTime ?? tomorrow).compareTo(b.startTime ?? tomorrow));
    final weekly = await RoutineAssistant.weeklyFor(tomorrow);
    final open = todayTasks.where((t) => !(t.isCompleted || t.status == 'completed') && t.status != 'running').toList();
    final weekdayBn = DateFormat('EEEE', _bn ? 'bn' : 'en').format(tomorrow);

    final b = StringBuffer(trx('🌙 **Plan for tomorrow** ($weekdayBn, ${DateFormat('d MMM').format(tomorrow)})', '🌙 **কালকের প্ল্যান** ($weekdayBn, ${_d(DateFormat('d MMM').format(tomorrow))})'));
    final actions = <Map<String, dynamic>>[];

    if (open.isNotEmpty) {
      b.write(_d(trx('\n\n📌 Left from today (${open.length}): ', '\n\n📌 আজ বাকি (${open.length}টা): ')));
      b.write(open.take(5).map(_name).join(', '));
      actions.add(_act(_d(trx('📅 Move all ${open.length} to tomorrow', '📅 ${open.length}টাই কালকে নাও')), 'move_unfinished'));
    }

    if (tTasks.isEmpty) {
      b.write(trx('\n\n🗓️ Tomorrow is empty so far.', '\n\n🗓️ কালকের রুটিনে এখনো কিছু নেই।'));
    } else {
      b.write(_d(trx('\n\n🗓️ Already planned (${tTasks.length}):', '\n\n🗓️ কালকের রুটিনে আছে (${tTasks.length}টা):')));
      for (final t in tTasks.take(8)) {
        b.write('\n• ${_name(t)} — ${_range(t)}');
      }
      // একই সময়ে দুটো টাস্ক
      for (var i = 0; i < tTasks.length; i++) {
        final t = tTasks[i];
        if (t.startTime == null) continue;
        final o = RoutineIntentParser.overlaps(tTasks.sublist(i + 1), t.startTime!, t.endTime ?? t.startTime!.add(const Duration(hours: 1)));
        if (o.isNotEmpty) {
          b.write(trx('\n⚠️ **${_name(t)}** and **${_name(o.first)}** overlap.', '\n⚠️ **${_name(t)}** আর **${_name(o.first)}**-এর সময় মিলে যাচ্ছে।'));
        }
      }
      final total = tTasks.fold<int>(0, (s, t) => s + t.totalDurationMinutes);
      if (total > 0) b.write(trx('\n⏱️ Total: ${_mins(total)}', '\n⏱️ মোট: ${_mins(total)}'));
      if (total > 10 * 60) b.write(trx(' — that\'s a lot, keep some breaks.', ' — অনেক বেশি, মাঝে বিরতি রাখুন।'));
    }

    final weeklyCopied = tTasks.any((t) => t.title.startsWith('[WR]'));
    if (weekly.isNotEmpty && !weeklyCopied) {
      b.write(_d(trx('\n\n🔁 Your weekly routine has ${weekly.length} task(s) for $weekdayBn.', '\n\n🔁 সাপ্তাহিক রুটিনে $weekdayBn-এর ${weekly.length}টা টাস্ক আছে।')));
      actions.add(_act(trx('🔁 Put weekly routine on tomorrow', '🔁 সাপ্তাহিক রুটিন কালকে বসাও'), 'copy_weekly', {'day': tomorrow.millisecondsSinceEpoch}));
    }

    b.write(trx('\n\n➕ To add, just type: _tomorrow 7am Math 2 hours_', '\n\n➕ নতুন যোগ করতে লিখুন: _কাল সকাল ৭টায় গণিত ২ ঘণ্টা_'));
    actions.add(_act(trx('➕ Add for tomorrow', '➕ কালকের জন্য যোগ'), 'fill', {'text': trx('tomorrow 7am ', 'কাল সকাল ৭টায় ')}));
    _botSay(b.toString(), actions: actions);
  }

  Future<void> _rbMoveUnfinished() async {
    final n = await RoutineAssistant.moveUnfinishedToTomorrow();
    if (n == 0) {
      _botSay(trx('👍 Nothing left over today.', '👍 আজকের কোনো টাস্ক বাকি নেই।'));
    } else {
      _botSay(_d(trx('📅 Moved $n unfinished task(s) to tomorrow, same times.', '📅 আজকের বাকি $nটা টাস্ক কালকে একই সময়ে নিয়ে গেলাম।')),
          actions: [_act(trx('🌙 See tomorrow', '🌙 কালকের প্ল্যান দেখি'), 'plan_tomorrow')]);
    }
  }

  // ---------------- বাটন চাপলে ----------------
  Future<void> _runRoutineAction(Map<String, dynamic> a) async {
    final type = a['type'] as String? ?? '';
    final data = Map<String, dynamic>.from(a['data'] as Map? ?? {});
    DateTime day() => DateTime.fromMillisecondsSinceEpoch(data['day'] as int);
    Task task() => RoutineAssistant.taskFromJson(Map<String, dynamic>.from(data['task'] as Map));
    try {
      switch (type) {
        case 'start':
          await RoutineAssistant.start(day(), task());
          _botSay(trx('▶ Started **${_name(task())}**. Good luck! Open Home to see the timer.', '▶ **${_name(task())}** শুরু হলো। শুভকামনা! টাইমার দেখতে Home-এ যান।'));
        case 'complete':
          await RoutineAssistant.complete(day(), task());
          _botSay(trx('✅ **${_name(task())}** done. +10 XP!', '✅ **${_name(task())}** শেষ। +১০ XP!'), actions: [_act(trx('▶ What next?', '▶ এরপর কী?'), 'what_now')]);
        case 'postpone':
          await _rbApply(RoutineIntentType.postpone, day(), task(), amount: (data['min'] as int?) ?? 15);
        case 'tomorrow':
          await _rbApply(RoutineIntentType.moveToDay, day(), task(), amount: 1);
        case 'undo':
          final from = data['removeFrom'] as int?;
          await RoutineAssistant.restore(day(), task(), removeFromDay: from != null ? DateTime.fromMillisecondsSinceEpoch(from) : null);
          _botSay(trx('↩ Restored **${_name(task())}** (${_range(task())}).', '↩ আগের মতো করে দিলাম: **${_name(task())}** (${_range(task())})।'));
        case 'undo_add':
          await RoutineAssistant.removeTask(day(), data['id'] as String);
          _botSay(trx('↩ Cancelled.', '↩ বাতিল করলাম।'));
        case 'pick':
          final it = RoutineIntentType.values.firstWhere((e) => e.name == data['intent'], orElse: () => RoutineIntentType.postpone);
          await _rbApply(it, day(), task(), amount: (data['amount'] as int?) ?? 0, raw: data['raw'] as String? ?? '');
        case 'add':
          await _rbAdd(data['raw'] as String? ?? '');
        case 'move_unfinished':
          await _rbMoveUnfinished();
        case 'copy_weekly':
          final n = await RoutineAssistant.copyWeeklyTo(day());
          _botSay(_d(trx('🔁 Added $n task(s) from your weekly routine to tomorrow.', '🔁 সাপ্তাহিক রুটিনের $nটা টাস্ক কালকের রুটিনে বসালাম।')),
              actions: [_act(trx('🌙 See tomorrow', '🌙 কালকের প্ল্যান দেখি'), 'plan_tomorrow')]);
        case 'what_now':
          await _rbWhatNow();
        case 'plan_tomorrow':
          await _rbPlanTomorrow();
      }
    } catch (e) {
      _botSay(trx('⚠️ Could not do that: $e', '⚠️ কাজটা করা গেল না: $e'));
    }
  }

  // ---------------- নোটিফিকেশন থেকে খোলা ----------------
  Future<void> _runInitialAction(String action) async {
    if (action == NightlySummaryService.openBotPlan) {
      await _rbPlanTomorrow();
      return;
    }
    final bar = action.indexOf('|');
    if (bar < 0) {
      await _rbWhatNow();
      return;
    }
    final kind = action.substring(0, bar);
    Map<String, dynamic> p;
    try {
      p = jsonDecode(action.substring(bar + 1)) as Map<String, dynamic>;
    } catch (_) {
      await _rbWhatNow();
      return;
    }
    final day = DateTime.tryParse(p['date'] as String? ?? '') ?? DateTime.now();
    final tasks = await RoutineAssistant.loadDay(day);
    final t = tasks.where((x) => x.id == p['taskId']).firstOrNull;
    if (t == null) {
      await _rbWhatNow();
      return;
    }
    if (kind == TaskNotificationActions.actionPostpone15) {
      await _rbApply(RoutineIntentType.postpone, day, t, amount: 15);
    } else if (kind == TaskNotificationActions.actionTomorrow) {
      await _rbApply(RoutineIntentType.moveToDay, day, t, amount: 1);
    } else {
      _botSay(
        trx('⏰ **${_name(t)}** was due at ${_clock(t.startTime ?? DateTime.now())} (${_range(t)}). What would you like to do?',
            '⏰ **${_name(t)}** ${_clock(t.startTime ?? DateTime.now())}-এ শুরু হওয়ার কথা ছিল (${_range(t)})। কী করবেন?'),
        actions: _taskButtons(day, t),
      );
    }
  }
}
