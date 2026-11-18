import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/disguise_menu.dart';
import 'disguise_screen.dart';
import 'pulse.dart';

class Mood {
  const Mood(this.label, this.emoji, this.icon, this.color);

  final String label;
  final String emoji;
  final IconData icon;
  final Color color;

  static const scale = [
    Mood('Awful', '😢', Icons.sentiment_very_dissatisfied, Color(0xFFD95B5B)),
    Mood('Low', '🙁', Icons.sentiment_dissatisfied, Color(0xFFEB8F5A)),
    Mood('Okay', '😐', Icons.sentiment_neutral, Color(0xFFE5B83E)),
    Mood('Good', '🙂', Icons.sentiment_satisfied, Color(0xFF6FB57A)),
    Mood('Great', '😄', Icons.sentiment_very_satisfied, Color(0xFF2E9373)),
  ];

  /// Moods saved by older versions, which had twelve.
  static const _older = {
    'Happy': 3, 'Loved': 4, 'Excited': 4, 'Energetic': 4, 'Motivated': 4,
    'Calm': 3, 'Thoughtful': 2, 'Tired': 1, 'Melancholy': 1, 'Sad': 0,
    'Stressed': 0, 'Anxious': 1,
  };

  static Mood? of(String label) {
    for (final m in scale) {
      if (m.label == label) return m;
    }
    final i = _older[label];
    return i == null ? null : scale[i];
  }
}

class MoodEntry {
  MoodEntry({required this.mood, this.emoji = '📝', required this.timestamp, this.note = ''});

  final String mood;
  final String emoji;
  final DateTime timestamp;
  final String note;

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'emoji': emoji,
        'timestamp': timestamp.toIso8601String(),
        if (note.isNotEmpty) 'note': note,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        mood: json['mood'] as String,
        emoji: json['emoji'] as String? ?? '📝',
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String? ?? '',
      );
}

const _teal = Color(0xFF2F8F83);

ThemeData moodTheme(Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: _teal,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    scaffoldBackgroundColor:
        brightness == Brightness.dark ? const Color(0xFF111416) : const Color(0xFFF3F6F7),
  );
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// A mood journal. A note that is a vault password opens the vault on Save.
class MoodSpaceDisguise extends StatefulWidget {
  const MoodSpaceDisguise({super.key, this.coach = false});

  final bool coach;

  @override
  State<MoodSpaceDisguise> createState() => _MoodSpaceDisguiseState();
}

class _MoodSpaceDisguiseState extends State<MoodSpaceDisguise> {
  static const _storageKey = 'mood_log_data';

  Map<String, List<MoodEntry>> _log = {};
  int _tab = 0;
  Mood? _picked;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || !mounted) return;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    setState(() {
      _log = decoded.map((day, list) => MapEntry(
          day,
          (list as List)
              .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
              .toList()));
    });
  }

  Future<void> _store() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode(_log.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()))),
    );
  }

  Future<void> _save() async {
    final note = _note.text;
    if (note.trim().isNotEmpty && await tryVaultCode(context, note)) {
      _note.clear();
      return;
    }
    if (!mounted) return;
    final mood = _picked;
    if (mood == null && note.trim().isEmpty) return;
    final now = DateTime.now();
    final entry = MoodEntry(
      mood: mood?.label ?? 'Note',
      emoji: mood?.emoji ?? '📝',
      timestamp: now,
      note: note.trim(),
    );
    setState(() {
      _log.putIfAbsent(_dateKey(now), () => []).add(entry);
      _picked = null;
    });
    _note.clear();
    FocusScope.of(context).unfocus();
    await _store();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to today')));
    }
  }

  List<MoodEntry> get _all =>
      _log.values.expand((e) => e).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: moodTheme(Theme.of(context).brightness),
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            titleSpacing: 20,
            title: const Row(
              children: [
                Icon(Icons.spa_outlined, color: _teal, size: 26),
                SizedBox(width: 10),
                Text('MoodSpace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: const [DisguiseMenu()],
          ),
          body: IndexedStack(
            index: _tab,
            children: [
              _today(context),
              _history(context),
              _MoodCalendar(log: _log),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.edit_note), label: 'Today'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
            ],
          ),
        );
      }),
    );
  }

  Widget _today(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final canSave = _picked != null || _note.text.trim().isNotEmpty;
    final save = SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: canSave ? _save : null,
        child: const Text('Save', style: TextStyle(fontSize: 16)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        const Text('How are you feeling?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final mood in Mood.scale)
              _MoodButton(
                mood: mood,
                selected: _picked == mood,
                onTap: () => setState(() => _picked = _picked == mood ? null : mood),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Add a note',
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        widget.coach ? Pulse(child: save) : save,
        const SizedBox(height: 32),
        Text('This week', style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        _WeekStrip(log: _log),
      ],
    );
  }

  Widget _history(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = _all;
    if (entries.isEmpty) {
      return Center(
        child: Text('Your check-ins appear here',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final mood = Mood.of(e.mood);
        final t = e.timestamp;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: CircleAvatar(
            backgroundColor: (mood?.color ?? scheme.outline).withValues(alpha: 0.18),
            child: mood != null
                ? Icon(mood.icon, color: mood.color)
                : Text(e.emoji, style: const TextStyle(fontSize: 18)),
          ),
          title: Text(e.mood, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: e.note.isEmpty ? null : Text(e.note, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            '${t.day} ${_months[t.month - 1].substring(0, 3)}\n'
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.selected, required this.onTap});

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: mood.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected ? mood.color : mood.color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(mood.icon, size: 32, color: selected ? Colors.white : mood.color),
            ),
            const SizedBox(height: 6),
            Text(mood.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

Color? _dayColor(Map<String, List<MoodEntry>> log, DateTime day) {
  final entries = log[_dateKey(day)];
  if (entries == null || entries.isEmpty) return null;
  return Mood.of(entries.last.mood)?.color ?? const Color(0xFF8A9499);
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.log});

  final Map<String, List<MoodEntry>> log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final day = monday.add(Duration(days: i));
              final color = _dayColor(log, day);
              final isToday = i == today.weekday - 1;
              return Column(
                children: [
                  Text(_weekdays[i][0],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                          color: isToday ? scheme.onSurface : scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color ?? Colors.transparent,
                      shape: BoxShape.circle,
                      border: color == null ? Border.all(color: scheme.outlineVariant, width: 2) : null,
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _MoodCalendar extends StatefulWidget {
  const _MoodCalendar({required this.log});

  final Map<String, List<MoodEntry>> log;

  @override
  State<_MoodCalendar> createState() => _MoodCalendarState();
}

class _MoodCalendarState extends State<_MoodCalendar> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final offset = first.weekday - 1;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text('${_months[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Text(d[0],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: offset + days,
            itemBuilder: (context, i) {
              if (i < offset) return const SizedBox.shrink();
              final day = DateTime(first.year, first.month, i - offset + 1);
              final color = _dayColor(widget.log, day);
              final isToday = _dateKey(day) == _dateKey(today);
              return Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: color?.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: isToday ? Border.all(color: scheme.onSurface, width: 1.5) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('${day.day}',
                      style: TextStyle(
                          fontSize: 15,
                          color: color != null ? Colors.white : scheme.onSurface)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
