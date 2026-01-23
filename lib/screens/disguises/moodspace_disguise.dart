import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/providers/app_state.dart';
import '../../core/widgets/disguise_menu.dart';

class MoodSpaceDisguise extends StatefulWidget {
  const MoodSpaceDisguise({super.key});

  @override
  State<MoodSpaceDisguise> createState() => _MoodSpaceDisguiseState();
}

class _MoodSpaceDisguiseState extends State<MoodSpaceDisguise> {
  final _moodController = TextEditingController();
  Map<String, List<MoodEntry>> _moodLogByDate = {};
  int _selectedTabIndex = 0;

  final List<MoodOption> _moodOptions = [
    MoodOption('😊', 'Happy', const Color(0xFFFFC107)),
    MoodOption('😢', 'Sad', const Color(0xFF2196F3)),
    MoodOption('😴', 'Tired', const Color(0xFF9C27B0)),
    MoodOption('🌟', 'Energetic', const Color(0xFFFF9800)),
    MoodOption('😌', 'Calm', const Color(0xFF4CAF50)),
    MoodOption('😤', 'Stressed', const Color(0xFFF44336)),
    MoodOption('🤔', 'Thoughtful', const Color(0xFF607D8B)),
    MoodOption('😍', 'Loved', const Color(0xFFE91E63)),
    MoodOption('😰', 'Anxious', const Color(0xFF795548)),
    MoodOption('🎉', 'Excited', const Color(0xFFFF5722)),
    MoodOption('😔', 'Melancholy', const Color(0xFF3F51B5)),
    MoodOption('💪', 'Motivated', const Color(0xFF009688)),
  ];

  @override
  void initState() {
    super.initState();
    _loadMoodLog();
  }

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodLog() async {
    final prefs = await SharedPreferences.getInstance();
    final moodJson = prefs.getString('mood_log_data');
    if (moodJson != null) {
      final Map<String, dynamic> decoded = json.decode(moodJson);
      setState(() {
        _moodLogByDate = decoded.map(
          (key, value) => MapEntry(
            key,
            (value as List).map((e) => MoodEntry.fromJson(e)).toList(),
          ),
        );
      });
    }
  }

  Future<void> _saveMoodLog() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      _moodLogByDate.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      ),
    );
    await prefs.setString('mood_log_data', encoded);
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addMoodEntry(String mood, {String? emoji}) async {
    final appState = context.read<AppState>();
    final unlocked = await appState.unlock(mood);

    if (unlocked && mounted) {
      Navigator.of(context).pushReplacementNamed('/vault');
      return;
    }

    final now = DateTime.now();
    final dateKey = _getDateKey(now);
    final entry = MoodEntry(mood: mood, emoji: emoji ?? '📝', timestamp: now);

    setState(() {
      if (_moodLogByDate[dateKey] == null) {
        _moodLogByDate[dateKey] = [];
      }
      _moodLogByDate[dateKey]!.add(entry);
    });
    await _saveMoodLog();
    _moodController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mood logged: $mood'),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
                : [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
          ),
        ),
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: isDark ? Colors.white : Colors.black87,
                displayColor: isDark ? Colors.white : Colors.black87,
              ),
              iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildDateHeader(isDark),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildLogMoodTab(isDark),
                      _buildHistoryTab(isDark),
                      _buildCalendarTab(isDark),
                    ],
                  ),
                ),
                _buildBottomNav(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/mood_icon.png',
            width: 32,
            height: 32,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 12),
          Text(
            'MoodSpace',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          DisguiseMenu(iconColor: isDark ? Colors.white : Colors.black87),
        ],
      ),
    );
  }

  Widget _buildDateHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        _getFormattedDate(),
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 14,
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}';
  }

  Widget _buildLogMoodTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How are you feeling?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _moodOptions.length,
                  itemBuilder: (context, index) {
                    final mood = _moodOptions[index];
                    return GestureDetector(
                      onTap: () => _addMoodEntry(mood.label, emoji: mood.emoji),
                      child: Container(
                        decoration: BoxDecoration(
                          color: mood.color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: mood.color.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  mood.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    mood.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Or write your own:',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _moodController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type how you\'re feeling...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _addMoodEntry(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_moodController.text.isNotEmpty) {
                        _addMoodEntry(_moodController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF764ba2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Mood',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTodayMoods(isDark),
        ],
      ),
    );
  }

  Widget _buildTodayMoods(bool isDark) {
    final todayKey = _getDateKey(DateTime.now());
    final todayMoods = _moodLogByDate[todayKey] ?? [];

    if (todayMoods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No moods logged today yet',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Moods',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...todayMoods.reversed
              .take(5)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(entry.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.mood,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final allEntries = <MoodEntry>[];
    _moodLogByDate.forEach((date, entries) {
      allEntries.addAll(entries);
    });
    allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (allEntries.isEmpty) {
      return Center(
        child: Text(
          'No mood history yet',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allEntries.length,
      itemBuilder: (context, index) {
        final entry = allEntries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(entry.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.mood,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatDateTime(entry.timestamp),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCalendarTab(bool isDark) {
    return MoodCalendarView(moodLogByDate: _moodLogByDate, isDark: isDark);
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.add_reaction, 'Log', isDark),
          _buildNavItem(1, Icons.history, 'History', isDark),
          _buildNavItem(2, Icons.calendar_month, 'Calendar', isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white54 : Colors.black38),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MoodOption {
  final String emoji;
  final String label;
  final Color color;

  MoodOption(this.emoji, this.label, this.color);
}

class MoodEntry {
  final String mood;
  final String emoji;
  final DateTime timestamp;

  MoodEntry({required this.mood, this.emoji = '📝', required this.timestamp});

  Map<String, dynamic> toJson() => {
    'mood': mood,
    'emoji': emoji,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    mood: json['mood'],
    emoji: json['emoji'] ?? '📝',
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class MoodCalendarView extends StatefulWidget {
  final Map<String, List<MoodEntry>> moodLogByDate;
  final bool isDark;

  const MoodCalendarView({
    super.key,
    required this.moodLogByDate,
    required this.isDark,
  });

  @override
  State<MoodCalendarView> createState() => _MoodCalendarViewState();
}

class _MoodCalendarViewState extends State<MoodCalendarView> {
  late DateTime _currentMonth;
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month - 1,
                  );
                }),
              ),
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month + 1,
                  );
                }),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => Text(
                    d,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildCalendarGrid()),
        if (_selectedDate != null &&
            widget.moodLogByDate[_selectedDate] != null)
          Container(
            height: 150,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moods on $_selectedDate',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.moodLogByDate[_selectedDate]!.length,
                    itemBuilder: (context, index) {
                      final entry = widget.moodLogByDate[_selectedDate]![index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              entry.emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.mood,
                                style: TextStyle(
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.white54
                                    : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final dayNumber = index - startingWeekday + 1;
        if (dayNumber < 1 || dayNumber > lastDayOfMonth.day) {
          return const SizedBox();
        }

        final dateKey =
            '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
        final moods = widget.moodLogByDate[dateKey];
        final hasMoods = moods?.isNotEmpty ?? false;
        final isSelected = _selectedDate == dateKey;
        final isToday =
            DateTime.now().year == _currentMonth.year &&
            DateTime.now().month == _currentMonth.month &&
            DateTime.now().day == dayNumber;

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = dateKey),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.6))
                  : (hasMoods
                        ? (widget.isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.4))
                        : null),
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      width: 2,
                    )
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasMoods)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      moods!.last.emoji,
                      style: const TextStyle(fontSize: 8),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
