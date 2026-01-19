import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

class ClockDisguise extends StatefulWidget {
  const ClockDisguise({super.key});

  @override
  State<ClockDisguise> createState() => _ClockDisguiseState();
}

class _ClockDisguiseState extends State<ClockDisguise>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  int _selectedTabIndex = 0;
  final List<Alarm> _alarms = [];
  String _secretCode = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _onTimeDigitTap(String digit) {
    setState(() {
      _secretCode += digit;
      if (_secretCode.length > 10) {
        _secretCode = _secretCode.substring(1);
      }
    });
    _tryUnlock();
  }

  Future<void> _tryUnlock() async {
    if (_secretCode.length >= 4) {
      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(_secretCode);
      if (unlocked && mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
      }
    }
  }

  void _showAlarmPicker() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null && mounted) {
      final codeStr =
          '${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}';

      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(codeStr);

      if (unlocked && mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
        return;
      }

      setState(() {
        _alarms.add(Alarm(time: time, isEnabled: true, label: 'Alarm'));
        _alarms.sort((a, b) {
          final aMinutes = a.time.hour * 60 + a.time.minute;
          final bMinutes = b.time.hour * 60 + b.time.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTab('Clock', 0),
                  _buildTab('Alarm', 1),
                  _buildTab('Stopwatch', 2),
                  _buildTab('Timer', 3),
                  _buildTab('World', 4),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildClockTab(),
                  _buildAlarmTab(),
                  const StopwatchWidget(),
                  const TimerWidget(),
                  const WorldClockWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? FloatingActionButton(
              onPressed: _showAlarmPicker,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.orange : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildClockTab() {
    final hour = _currentTime.hour.toString().padLeft(2, '0');
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeDigit(hour[0]),
              _buildTimeDigit(hour[1]),
              const Text(
                ':',
                style: TextStyle(fontSize: 72, color: Colors.white),
              ),
              _buildTimeDigit(minute[0]),
              _buildTimeDigit(minute[1]),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            ':$second',
            style: const TextStyle(fontSize: 32, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          Text(
            _formatDate(_currentTime),
            style: const TextStyle(fontSize: 18, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDigit(String digit) {
    return GestureDetector(
      onTap: () => _onTimeDigitTap(digit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w300,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmTab() {
    if (_alarms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No alarms set',
              style: TextStyle(fontSize: 18, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add an alarm',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _alarms.length,
      itemBuilder: (context, index) {
        final alarm = _alarms[index];
        return Dismissible(
          key: Key(alarm.time.toString() + index.toString()),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            setState(() {
              _alarms.removeAt(index);
            });
          },
          child: ListTile(
            title: Text(
              alarm.time.format(context),
              style: TextStyle(
                fontSize: 32,
                color: alarm.isEnabled ? Colors.white : Colors.white38,
              ),
            ),
            subtitle: Text(
              alarm.label,
              style: TextStyle(color: Colors.white54),
            ),
            trailing: Switch(
              value: alarm.isEnabled,
              onChanged: (value) {
                setState(() {
                  _alarms[index] = Alarm(
                    time: alarm.time,
                    isEnabled: value,
                    label: alarm.label,
                  );
                });
              },
              activeTrackColor: Colors.orange,
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
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
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class Alarm {
  final TimeOfDay time;
  final bool isEnabled;
  final String label;

  Alarm({required this.time, required this.isEnabled, required this.label});
}

class StopwatchWidget extends StatefulWidget {
  const StopwatchWidget({super.key});

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();
}

class _StopwatchWidgetState extends State<StopwatchWidget> {
  int _milliseconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  final List<int> _laps = [];

  void _startStop() {
    setState(() {
      if (_isRunning) {
        _timer?.cancel();
        _isRunning = false;
      } else {
        _isRunning = true;
        _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
          setState(() {
            _milliseconds += 10;
          });
        });
      }
    });
  }

  void _lap() {
    if (_isRunning) {
      setState(() {
        _laps.insert(0, _milliseconds);
      });
    }
  }

  void _reset() {
    setState(() {
      _timer?.cancel();
      _isRunning = false;
      _milliseconds = 0;
      _laps.clear();
    });
  }

  String _formatTime(int ms) {
    final hours = (ms ~/ 3600000).toString().padLeft(2, '0');
    final minutes = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final centiseconds = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds.$centiseconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              _formatTime(_milliseconds),
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              onPressed: _isRunning ? _lap : _reset,
              backgroundColor: Colors.grey[700],
              heroTag: 'stopwatch_lap',
              child: Icon(_isRunning ? Icons.flag : Icons.refresh),
            ),
            const SizedBox(width: 32),
            FloatingActionButton.large(
              onPressed: _startStop,
              backgroundColor: _isRunning ? Colors.red : Colors.green,
              heroTag: 'stopwatch_startstop',
              child: Icon(
                _isRunning ? Icons.pause : Icons.play_arrow,
                size: 36,
              ),
            ),
            const SizedBox(width: 32),
            FloatingActionButton(
              onPressed: _reset,
              backgroundColor: Colors.grey[700],
              heroTag: 'stopwatch_reset',
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          flex: 2,
          child: _laps.isEmpty
              ? const Center(
                  child: Text(
                    'No laps recorded',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: _laps.length,
                  itemBuilder: (context, index) {
                    final lapTime = _laps[index];
                    final prevTime = index < _laps.length - 1
                        ? _laps[index + 1]
                        : 0;
                    final diff = lapTime - prevTime;
                    return ListTile(
                      leading: Text(
                        'Lap ${_laps.length - index}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      title: Text(
                        _formatTime(lapTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: Text(
                        '+${_formatTime(diff)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;
  int _selectedHours = 0;
  int _selectedMinutes = 0;
  int _selectedSeconds = 0;

  Future<void> _startTimer() async {
    if (_totalSeconds == 0) {
      _totalSeconds =
          _selectedHours * 3600 + _selectedMinutes * 60 + _selectedSeconds;
    }

    if (_totalSeconds == 0) return;

    final minutes = _totalSeconds ~/ 60;
    final appState = context.read<AppState>();
    final unlocked = await appState.unlock(minutes.toString());

    if (unlocked && mounted) {
      Navigator.of(context).pushReplacementNamed('/vault');
      return;
    }

    if (!_isPaused) {
      _remainingSeconds = _totalSeconds;
    }

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _showTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = 0;
      _totalSeconds = 0;
    });
  }

  void _showTimerComplete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Timer Complete',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your timer has finished!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRunning || _isPaused) {
      return _buildRunningTimer();
    }
    return _buildTimerPicker();
  }

  Widget _buildTimerPicker() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Set Timer Duration',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Setting a specific duration may unlock features',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPicker(
              'Hours',
              _selectedHours,
              24,
              (v) => setState(() => _selectedHours = v),
            ),
            const Text(
              ':',
              style: TextStyle(color: Colors.white, fontSize: 32),
            ),
            _buildPicker(
              'Minutes',
              _selectedMinutes,
              60,
              (v) => setState(() => _selectedMinutes = v),
            ),
            const Text(
              ':',
              style: TextStyle(color: Colors.white, fontSize: 32),
            ),
            _buildPicker(
              'Seconds',
              _selectedSeconds,
              60,
              (v) => setState(() => _selectedSeconds = v),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuickButton('1m', () => _setQuickTime(1)),
            _buildQuickButton('5m', () => _setQuickTime(5)),
            _buildQuickButton('10m', () => _setQuickTime(10)),
            _buildQuickButton('15m', () => _setQuickTime(15)),
            _buildQuickButton('30m', () => _setQuickTime(30)),
          ],
        ),
        const SizedBox(height: 48),
        FloatingActionButton.large(
          onPressed:
              (_selectedHours > 0 ||
                  _selectedMinutes > 0 ||
                  _selectedSeconds > 0)
              ? _startTimer
              : null,
          backgroundColor: Colors.green,
          heroTag: 'timer_start',
          child: const Icon(Icons.play_arrow, size: 36),
        ),
      ],
    );
  }

  void _setQuickTime(int minutes) {
    setState(() {
      _selectedHours = 0;
      _selectedMinutes = minutes;
      _selectedSeconds = 0;
    });
  }

  Widget _buildQuickButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildPicker(
    String label,
    int value,
    int max,
    Function(int) onChanged,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          height: 150,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 50,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: max,
              builder: (context, index) => Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: index == value ? Colors.orange : Colors.white54,
                    fontSize: index == value ? 32 : 24,
                    fontWeight: index == value
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunningTimer() {
    final hours = (_remainingSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_remainingSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    final progress = _totalSeconds > 0
        ? _remainingSeconds / _totalSeconds
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation(Colors.orange),
              ),
            ),
            Text(
              '$hours:$minutes:$seconds',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              onPressed: _resetTimer,
              backgroundColor: Colors.grey[700],
              heroTag: 'timer_reset',
              child: const Icon(Icons.stop),
            ),
            const SizedBox(width: 32),
            FloatingActionButton.large(
              onPressed: _isRunning ? _pauseTimer : _startTimer,
              backgroundColor: _isRunning ? Colors.orange : Colors.green,
              heroTag: 'timer_pauseplay',
              child: Icon(
                _isRunning ? Icons.pause : Icons.play_arrow,
                size: 36,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WorldClockWidget extends StatefulWidget {
  const WorldClockWidget({super.key});

  @override
  State<WorldClockWidget> createState() => _WorldClockWidgetState();
}

class _WorldClockWidgetState extends State<WorldClockWidget> {
  String _enteredCode = '';
  final List<Map<String, dynamic>> _worldClocks = [
    {'city': 'New York', 'offset': -5, 'country': 'USA'},
    {'city': 'London', 'offset': 0, 'country': 'UK'},
    {'city': 'Tokyo', 'offset': 9, 'country': 'Japan'},
    {'city': 'Sydney', 'offset': 11, 'country': 'Australia'},
    {'city': 'Dubai', 'offset': 4, 'country': 'UAE'},
    {'city': 'Paris', 'offset': 1, 'country': 'France'},
  ];

  Future<void> _onKeyTap(String key) async {
    if (key == 'clear') {
      setState(() => _enteredCode = '');
      return;
    }
    if (key == 'back') {
      if (_enteredCode.isNotEmpty) {
        setState(() => _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1));
      }
      return;
    }
    
    setState(() => _enteredCode += key);
    
    if (_enteredCode.length >= 4) {
      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(_enteredCode);
      if (unlocked && mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
      }
    }
  }

  String _getTimeForOffset(int offset) {
    final now = DateTime.now().toUtc().add(Duration(hours: offset));
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Search City',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _enteredCode.isEmpty ? 'Type to search...' : _enteredCode,
                        style: TextStyle(
                          color: _enteredCode.isEmpty ? Colors.white38 : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_enteredCode.isNotEmpty)
                      GestureDetector(
                        onTap: () => _onKeyTap('clear'),
                        child: const Icon(Icons.close, color: Colors.white54),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _worldClocks.length,
            itemBuilder: (context, index) {
              final clock = _worldClocks[index];
              return ListTile(
                title: Text(
                  clock['city'],
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  clock['country'],
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Text(
                  _getTimeForOffset(clock['offset']),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['1', '2', '3', 'A', 'B', 'C'].map((k) => _buildKey(k)).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['4', '5', '6', 'D', 'E', 'F'].map((k) => _buildKey(k)).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['7', '8', '9', 'G', 'H', 'I'].map((k) => _buildKey(k)).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKey('clear', label: 'CLR'),
                  _buildKey('0'),
                  _buildKey('back', icon: Icons.backspace_outlined),
                  _buildKey('J'),
                  _buildKey('K'),
                  _buildKey('L'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String key, {String? label, IconData? icon}) {
    return GestureDetector(
      onTap: () => _onKeyTap(key),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 20)
              : Text(
                  label ?? key,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
        ),
      ),
    );
  }
}
