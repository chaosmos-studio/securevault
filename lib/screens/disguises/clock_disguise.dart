import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/disguise_menu.dart';
import '../../ui/text_prompt.dart';
import 'disguise_screen.dart';
import 'pulse.dart';

ThemeData clockTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFF3D6FD8),
      fontFamily: 'Roboto',
    );

class Alarm {
  Alarm({required this.time, required this.enabled, required this.label});

  final TimeOfDay time;
  final bool enabled;
  final String label;

  Map<String, Object> toJson() =>
      {'hour': time.hour, 'minute': time.minute, 'enabled': enabled, 'label': label};

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
        enabled: json['enabled'] as bool? ?? true,
        label: json['label'] as String? ?? '',
      );

  Alarm copyWith({TimeOfDay? time, bool? enabled, String? label}) => Alarm(
        time: time ?? this.time,
        enabled: enabled ?? this.enabled,
        label: label ?? this.label,
      );
}

/// A clock app with alarms, a timer and a stopwatch. A vault PIN typed on the
/// timer's keypad and started opens the vault, and so does an alarm whose
/// label, or whose time as four digits, is a vault password.
class ClockDisguise extends StatefulWidget {
  const ClockDisguise({super.key, this.coach = false});

  final bool coach;

  @override
  State<ClockDisguise> createState() => _ClockDisguiseState();
}

class _ClockDisguiseState extends State<ClockDisguise> {
  late int _tab = widget.coach ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: clockTheme(brightness),
      child: Builder(builder: (context) {
        const titles = ['Alarm', 'Clock', 'Timer', 'Stopwatch'];
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_tab],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
            actions: const [DisguiseMenu()],
          ),
          body: IndexedStack(
            index: _tab,
            children: [
              const _AlarmTab(),
              const _ClockTab(),
              _TimerTab(coach: widget.coach),
              const _StopwatchTab(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.alarm), label: 'Alarm'),
              NavigationDestination(icon: Icon(Icons.schedule), label: 'Clock'),
              NavigationDestination(icon: Icon(Icons.hourglass_empty), label: 'Timer'),
              NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Stopwatch'),
            ],
          ),
        );
      }),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

class _ClockTab extends StatefulWidget {
  const _ClockTab();

  @override
  State<_ClockTab> createState() => _ClockTabState();
}

class _ClockTabState extends State<_ClockTab> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
    final hour = use24 ? _now.hour : (_now.hour % 12 == 0 ? 12 : _now.hour % 12);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return LayoutBuilder(builder: (context, box) {
      final dial = math.min(box.maxWidth * 0.72, box.maxHeight * 0.5);
      return Column(
        children: [
          SizedBox(height: box.maxHeight * 0.06),
          SizedBox(
            width: dial,
            height: dial,
            child: CustomPaint(painter: _DialPainter(_now, scheme)),
          ),
          SizedBox(height: box.maxHeight * 0.05),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${use24 ? _two(hour) : hour}:${_two(_now.minute)}',
                  style: TextStyle(
                      fontSize: 64, fontWeight: FontWeight.w300, color: scheme.onSurface)),
              if (!use24)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_now.hour < 12 ? 'AM' : 'PM',
                      style: TextStyle(fontSize: 22, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${weekdays[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]}',
            style: TextStyle(fontSize: 17, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    });
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.now, this.scheme);

  final DateTime now;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = scheme.surfaceContainerHigh);
    final tick = Paint()
      ..color = scheme.onSurfaceVariant
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawCircle(c + dir * r * 0.84, r * (i % 3 == 0 ? 0.03 : 0.018), tick);
    }
    void hand(double turns, double length, double width, Color color) {
      final a = turns * 2 * math.pi;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
          c,
          c + dir * r * length,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
    }

    final seconds = now.second;
    final minutes = now.minute + seconds / 60;
    final hours = (now.hour % 12) + minutes / 60;
    hand(hours / 12, 0.48, r * 0.07, scheme.onSurface);
    hand(minutes / 60, 0.68, r * 0.045, scheme.primary);
    hand(seconds / 60, 0.74, r * 0.016, scheme.tertiary);
    canvas.drawCircle(c, r * 0.045, Paint()..color = scheme.onSurface);
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.now != now || old.scheme != scheme;
}

class _AlarmTab extends StatefulWidget {
  const _AlarmTab();

  @override
  State<_AlarmTab> createState() => _AlarmTabState();
}

class _AlarmTabState extends State<_AlarmTab> {
  static const _storageKey = 'clock_alarms';
  List<Alarm> _alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || !mounted) return;
    setState(() {
      _alarms = (json.decode(raw) as List)
          .map((a) => Alarm.fromJson(a as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _save() async {
    _alarms.sort((a, b) =>
        (a.time.hour * 60 + a.time.minute).compareTo(b.time.hour * 60 + b.time.minute));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, json.encode(_alarms.map((a) => a.toJson()).toList()));
  }

  /// Asks for a time and a label. Returns null when the alarm opened the vault
  /// or was cancelled.
  Future<Alarm?> _edit(Alarm? alarm) async {
    final time = await showTimePicker(
      context: context,
      initialTime: alarm?.time ?? TimeOfDay.now(),
    );
    if (time == null || !mounted) return null;
    final label = await askText(context, title: 'Label', initial: alarm?.label ?? '', hint: 'Alarm');
    if (label == null || !mounted) return null;
    if (await tryVaultCode(context, label)) return null;
    if (!mounted) return null;
    if (await tryVaultCode(context, '${_two(time.hour)}${_two(time.minute)}')) return null;
    return Alarm(time: time, enabled: alarm?.enabled ?? true, label: label.trim());
  }

  Future<void> _add() async {
    final alarm = await _edit(null);
    if (alarm == null) return;
    setState(() => _alarms.add(alarm));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: _alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm, size: 72, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No alarms', style: TextStyle(fontSize: 17, color: scheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              itemCount: _alarms.length,
              itemBuilder: (context, i) {
                final alarm = _alarms[i];
                final faded = alarm.enabled ? scheme.onSurface : scheme.onSurfaceVariant;
                return Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      final edited = await _edit(alarm);
                      if (edited == null) return;
                      setState(() => _alarms[i] = edited);
                      _save();
                    },
                    onLongPress: () {
                      setState(() => _alarms.removeAt(i));
                      _save();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (alarm.label.isNotEmpty)
                                  Text(alarm.label,
                                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                                Text(alarm.time.format(context),
                                    style: TextStyle(
                                        fontSize: 44, fontWeight: FontWeight.w300, color: faded)),
                              ],
                            ),
                          ),
                          Switch(
                            value: alarm.enabled,
                            onChanged: (v) {
                              setState(() => _alarms[i] = alarm.copyWith(enabled: v));
                              _save();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.large(
        heroTag: null,
        onPressed: _add,
        tooltip: 'Add alarm',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TimerTab extends StatefulWidget {
  const _TimerTab({required this.coach});

  final bool coach;

  @override
  State<_TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<_TimerTab> {
  /// Every digit typed; the display shows the last six as h m s.
  String _typed = '';
  int _total = 0;
  int _left = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _six => _typed.length > 6
      ? _typed.substring(_typed.length - 6)
      : _typed.padLeft(6, '0');

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
      } else if (_typed.length < 16) {
        _typed += k;
      }
    });
  }

  Future<void> _start() async {
    if (_typed.isEmpty) return;
    if (await tryVaultCode(context, _typed)) return;
    final six = _six;
    final seconds = int.parse(six.substring(0, 2)) * 3600 +
        int.parse(six.substring(2, 4)) * 60 +
        int.parse(six.substring(4, 6));
    if (seconds == 0) return;
    setState(() {
      _total = seconds;
      _left = seconds;
      _typed = '';
    });
    _run();
  }

  void _run() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        setState(() => _total = 0);
      }
    });
  }

  void _pauseOrResume() {
    if (_ticker?.isActive ?? false) {
      _ticker?.cancel();
      setState(() {});
    } else {
      _run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_total > 0) return _running(scheme);

    final six = _six;
    final entered = _typed.length;
    TextSpan part(String digits, String unit, int index) {
      final lit = 6 - index * 2 <= entered;
      final color = lit ? scheme.primary : scheme.onSurfaceVariant;
      return TextSpan(children: [
        TextSpan(text: digits, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: color)),
        TextSpan(text: unit, style: TextStyle(fontSize: 22, color: color)),
        const TextSpan(text: '  '),
      ]);
    }

    final start = FloatingActionButton.large(
      heroTag: null,
      onPressed: entered == 0 ? null : _start,
      tooltip: 'Start',
      backgroundColor: entered == 0 ? scheme.surfaceContainerHighest : scheme.primary,
      foregroundColor: entered == 0 ? scheme.onSurfaceVariant : scheme.onPrimary,
      child: const Icon(Icons.play_arrow_rounded, size: 40),
    );

    return LayoutBuilder(builder: (context, box) {
      final keySize = math.min((box.maxWidth - 96) / 3, (box.maxHeight - 260) / 4);
      return Column(
        children: [
          const Spacer(),
          FittedBox(
            child: Text.rich(TextSpan(children: [
              part(six.substring(0, 2), 'h', 2),
              part(six.substring(2, 4), 'm', 1),
              part(six.substring(4, 6), 's', 0),
            ])),
          ),
          const Spacer(),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['00', '0', '⌫'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: SizedBox(
                      width: keySize,
                      height: keySize * 0.78,
                      child: Material(
                        color: scheme.surfaceContainerHigh,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () {
                            for (final digit in k == '00' ? ['0', '0'] : [k]) {
                              _key(digit);
                            }
                          },
                          child: Center(
                            child: k == '⌫'
                                ? const Icon(Icons.backspace_outlined)
                                : Text(k, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          widget.coach ? Pulse(child: start) : start,
          const SizedBox(height: 20),
        ],
      );
    });
  }

  Widget _running(ColorScheme scheme) {
    final running = _ticker?.isActive ?? false;
    final h = _left ~/ 3600, m = (_left % 3600) ~/ 60, s = _left % 60;
    return Column(
      children: [
        const Spacer(),
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _left / _total,
                strokeWidth: 8,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
              Center(
                child: Text(
                  h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}',
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w300),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: () {
                _ticker?.cancel();
                setState(() => _total = 0);
              },
              child: const Text('Delete'),
            ),
            const SizedBox(width: 24),
            FloatingActionButton.large(
              heroTag: null,
              onPressed: _pauseOrResume,
              child: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _StopwatchTab extends StatefulWidget {
  const _StopwatchTab();

  @override
  State<_StopwatchTab> createState() => _StopwatchTabState();
}

class _StopwatchTabState extends State<_StopwatchTab> {
  final _watch = Stopwatch();
  final List<Duration> _laps = [];
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_watch.isRunning) {
        _watch.stop();
        _ticker?.cancel();
      } else {
        _watch.start();
        _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60, cs = (d.inMilliseconds % 1000) ~/ 10;
    return '${_two(m)}:${_two(s)}.${_two(cs)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elapsed = _watch.elapsed;
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(_format(elapsed),
            style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w300,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: _laps.length,
            itemBuilder: (context, i) {
              final n = _laps.length - i;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text('# $n', style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(_format(_laps[i]),
                        style: const TextStyle(
                            fontSize: 16, fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: elapsed == Duration.zero
                  ? null
                  : () => setState(() {
                        if (_watch.isRunning) {
                          _laps.insert(0, _watch.elapsed);
                        } else {
                          _watch.reset();
                          _laps.clear();
                        }
                      }),
              child: Text(_watch.isRunning ? 'Lap' : 'Reset'),
            ),
            const SizedBox(width: 24),
            FloatingActionButton.large(
              heroTag: null,
              onPressed: _toggle,
              tooltip: _watch.isRunning ? 'Pause' : 'Start',
              child: Icon(_watch.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 40),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
