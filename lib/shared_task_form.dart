// lib/shared_task_form.dart
import 'package:flutter/material.dart';
import 'daily_routine.dart';
import 'package:easy_localization/easy_localization.dart';

class SharedTaskForm extends StatefulWidget {
  final Function(Task) onSubmit;
  final List<String> categories;
  const SharedTaskForm({
    Key? key,
    required this.onSubmit,
    required this.categories,
  }) : super(key: key);

  @override
  State<SharedTaskForm> createState() => _SharedTaskFormState();
}

class _SharedTaskFormState extends State<SharedTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isPrivate = false;
  String _selectedCategory = 'Study';
  String? _timeError;

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _handleSubmit() {
    setState(() => _timeError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startTime == null || _endTime == null) {
      setState(() => _timeError = 'Please select both start and end times.');
      return;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
    var end = DateTime(now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    final bufferTime = now.subtract(const Duration(minutes: 1));
    if (start.isBefore(bufferTime)) {
      setState(() => _timeError = 'Start time cannot be in the past!');
      return;
    }
    if (end.isBefore(bufferTime)) {
      setState(() => _timeError = 'End time cannot be in the past!');
      return;
    }
    final durationMinutes = end.difference(start).inMinutes;
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _subjectController.text.trim(),
      subject: _subjectController.text.trim(),
      topic: _topicController.text.trim(),
      challenges: _challengesController.text.trim(),
      notes: _notesController.text.trim(),
      startTime: start,
      endTime: end,
      isPrivate: _isPrivate,
      category: _selectedCategory,
      totalDurationMinutes: durationMinutes,
    );
    widget.onSubmit(newTask);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _challengesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = colorScheme.onSurface;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subject
            Text('Subject Name (বিষয়)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: 'Enter Subject Name',
                hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.6)),
                prefixIcon: Icon(Icons.subject, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter a subject name' : null,
            ),
            const SizedBox(height: 16),
            // Topic
            Text('Topic Name (বিষয়বস্তু)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _topicController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: 'Enter Topic Name',
                hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.6)),
                prefixIcon: Icon(Icons.title_rounded, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            // Challenges
            Text('Possible Challenges (সম্ভাব্য সমস্যা)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _challengesController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: 'Describe potential issues or difficulties...',
                hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.6)),
                prefixIcon: Icon(Icons.warning_amber_rounded, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            // Notes
            Text('Task Goal / Notes (লক্ষ্য ও নোট)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              style: TextStyle(color: onSurfaceColor),
              decoration: InputDecoration(
                hintText: 'Enter notes or specific goals...',
                hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.6)),
                prefixIcon: Icon(Icons.notes, color: colorScheme.primary),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            // Category dropdown
            Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: onSurfaceColor)))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: onSurfaceColor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),
            // Private toggle
            Row(
              children: [
                Checkbox(value: _isPrivate, onChanged: (v) => setState(() => _isPrivate = v ?? false)),
                const Text('Private'),
              ],
            ),
            const SizedBox(height: 16),
            // Time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(true),
                    icon: Icon(
                      Icons.access_time_rounded,
                      color: _startTime != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    label: Text(
                      _startTime == null ? 'Start Time' : _startTime!.format(context),
                      style: TextStyle(
                        color: _startTime != null ? colorScheme.primary : onSurfaceColor,
                        fontWeight: _startTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _startTime != null
                            ? colorScheme.primary
                            : onSurfaceColor.withValues(alpha: 0.3),
                        width: _startTime != null ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(false),
                    icon: Icon(
                      Icons.access_time_rounded,
                      color: _endTime != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    label: Text(
                      _endTime == null ? 'End Time' : _endTime!.format(context),
                      style: TextStyle(
                        color: _endTime != null ? colorScheme.primary : onSurfaceColor,
                        fontWeight: _endTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _endTime != null
                            ? colorScheme.primary
                            : onSurfaceColor.withValues(alpha: 0.3),
                        width: _endTime != null ? 1.5 : 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Inline error display
            if (_timeError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(_timeError!, style: const TextStyle(color: Colors.red)),
              ),
            // Save button
            ElevatedButton(
              onPressed: _handleSubmit,
              child: Text('Save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
