import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

class ClockDisguise extends StatefulWidget {
  const ClockDisguise({super.key});

  @override
  State<ClockDisguise> createState() => _ClockDisguiseState();
}

class _ClockDisguiseState extends State<ClockDisguise> with SingleTickerProviderStateMixin {
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
      final codeStr = '${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}';
      
      final appState = context.read<AppState>();
      final unlocked = await appState.unlock(codeStr);
      
      if (unlocked && mounted) {
        Navigator.of(context).pushReplacementNamed('/vault');
        return;
      }
      
      setState(() {
        _alarms.add(Alarm(time: time, isEnabled: true));
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
                  _buildTab('Timer', 2),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildClockTab(),
                  _buildAlarmTab(),
                  _buildTimerTab(),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.orange : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              const Text(':', style: TextStyle(fontSize: 72, color: Colors.white)),
              _buildTimeDigit(minute[0]),
              _buildTimeDigit(minute[1]),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            ':$second',
            style: TextStyle(fontSize: 32, color: Colors.white54),
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
            Icon(Icons.alarm_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'No alarms set',
              style: TextStyle(fontSize: 18, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _alarms.length,
      itemBuilder: (context, index) {
        final alarm = _alarms[index];
        return ListTile(
          title: Text(
            alarm.time.format(context),
            style: TextStyle(
              fontSize: 32,
              color: alarm.isEnabled ? Colors.white : Colors.white38,
            ),
          ),
          trailing: Switch(
            value: alarm.isEnabled,
            onChanged: (value) {
              setState(() {
                _alarms[index] = Alarm(time: alarm.time, isEnabled: value);
              });
            },
            activeTrackColor: Colors.orange,
          ),
          onLongPress: () {
            setState(() {
              _alarms.removeAt(index);
            });
          },
        );
      },
    );
  }

  Widget _buildTimerTab() {
    return const TimerWidget();
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class Alarm {
  final TimeOfDay time;
  final bool isEnabled;

  Alarm({required this.time, required this.isEnabled});
}

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  int _seconds = 0;
  bool _isRunning = false;
  Timer? _timer;

  void _startStop() {
    setState(() {
      if (_isRunning) {
        _timer?.cancel();
        _isRunning = false;
      } else {
        _isRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _seconds++;
          });
        });
      }
    });
  }

  void _reset() {
    setState(() {
      _timer?.cancel();
      _isRunning = false;
      _seconds = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$hours:$minutes:$secs',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: _reset,
                backgroundColor: Colors.grey[700],
                heroTag: 'reset',
                child: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 32),
              FloatingActionButton(
                onPressed: _startStop,
                backgroundColor: _isRunning ? Colors.red : Colors.green,
                heroTag: 'startstop',
                child: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
