import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/providers/app_state.dart';

class WeatherDisguise extends StatefulWidget {
  const WeatherDisguise({super.key});

  @override
  State<WeatherDisguise> createState() => _WeatherDisguiseState();
}

class _WeatherDisguiseState extends State<WeatherDisguise> {
  final _moodController = TextEditingController();

  String _locationName = 'Loading...';
  double? _temperature;
  String _condition = '';
  IconData _weatherIcon = Icons.cloud;
  List<HourlyForecast> _hourlyForecast = [];
  List<DailyForecast> _weekForecast = [];
  bool _isLoading = true;

  Map<String, List<MoodEntry>> _moodLogByDate = {};
  final List<String> _defaultMoods = [
    '😊 Happy',
    '😢 Sad',
    '😴 Tired',
    '🌟 Energetic',
    '😌 Calm',
    '🤔 Thoughtful',
  ];

  @override
  void initState() {
    super.initState();
    _loadMoodLog();
    _fetchWeatherData();
  }

  @override
  void dispose() {
    _moodController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodLog() async {
    final prefs = await SharedPreferences.getInstance();
    final moodJson = prefs.getString('weather_mood_log');
    if (moodJson != null) {
      final Map<String, dynamic> decoded = json.decode(moodJson);
      setState(() {
        _moodLogByDate = decoded.map((key, value) => MapEntry(
          key,
          (value as List).map((e) => MoodEntry.fromJson(e)).toList(),
        ));
      });
    }
  }

  Future<void> _saveMoodLog() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_moodLogByDate.map((key, value) => MapEntry(
      key,
      value.map((e) => e.toJson()).toList(),
    )));
    await prefs.setString('weather_mood_log', encoded);
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final geoUrl =
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json';
        final geoResponse = await http.get(
          Uri.parse(geoUrl),
          headers: {'User-Agent': 'SecureVault/1.0'},
        );

        String city = 'Current Location';
        if (geoResponse.statusCode == 200) {
          final geoData = json.decode(geoResponse.body);
          city =
              geoData['address']['city'] ??
              geoData['address']['town'] ??
              geoData['address']['village'] ??
              'Current Location';
        }

        setState(() {
          _locationName = city;
          _temperature = data['current']['temperature_2m']?.toDouble();
          final weatherCode = data['current']['weather_code'];
          _condition = _getConditionFromCode(weatherCode);
          _weatherIcon = _getIconFromCode(weatherCode);

          _hourlyForecast = [];
          final hourlyTemps = data['hourly']['temperature_2m'] as List;
          final hourlyCodes = data['hourly']['weather_code'] as List;
          final now = DateTime.now();
          for (int i = 0; i < 24 && i < hourlyTemps.length; i++) {
            _hourlyForecast.add(
              HourlyForecast(
                hour: now.add(Duration(hours: i)),
                temp: hourlyTemps[i]?.toDouble() ?? 0,
                icon: _getIconFromCode(hourlyCodes[i]),
              ),
            );
          }

          _weekForecast = [];
          final dailyMax = data['daily']['temperature_2m_max'] as List;
          final dailyMin = data['daily']['temperature_2m_min'] as List;
          final dailyCodes = data['daily']['weather_code'] as List;
          for (int i = 0; i < 7 && i < dailyMax.length; i++) {
            _weekForecast.add(
              DailyForecast(
                date: now.add(Duration(days: i)),
                high: dailyMax[i]?.toDouble() ?? 0,
                low: dailyMin[i]?.toDouble() ?? 0,
                icon: _getIconFromCode(dailyCodes[i]),
                condition: _getConditionFromCode(dailyCodes[i]),
              ),
            );
          }

          _isLoading = false;
        });
      } else {
        throw Exception('Weather API error');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationName = 'Location unavailable';
        _temperature = 22;
        _condition = 'Partly Cloudy';
        _weatherIcon = Icons.cloud_queue;
      });
    }
  }

  String _getConditionFromCode(int? code) {
    if (code == null) return 'Unknown';
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 57) return 'Drizzle';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Showers';
    if (code <= 86) return 'Snow Showers';
    return 'Thunderstorm';
  }

  IconData _getIconFromCode(int? code) {
    if (code == null) return Icons.cloud;
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud_queue;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.water_drop;
    if (code <= 77) return Icons.ac_unit;
    if (code <= 86) return Icons.snowing;
    return Icons.thunderstorm;
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white70),
              title: const Text(
                'Refresh Weather',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _fetchWeatherData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.white70),
              title: const Text(
                'Update Location',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _fetchWeatherData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.thermostat, color: Colors.white70),
              title: const Text(
                'Temperature Unit',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Celsius',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodLogger() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'How are you feeling?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Log your mood about today\'s weather',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _defaultMoods
                    .map(
                      (mood) => ActionChip(
                        label: Text(mood),
                        backgroundColor: Colors.blue[700],
                        labelStyle: const TextStyle(color: Colors.white),
                        onPressed: () => _addMoodEntry(mood),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Or write your own:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _moodController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type how you\'re feeling...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
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
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Mood',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Moods:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMoodCalendar();
                    },
                    child: const Text('View Calendar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildTodayMoods(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayMoods() {
    final todayKey = _getDateKey(DateTime.now());
    final todayMoods = _moodLogByDate[todayKey] ?? [];
    
    if (todayMoods.isEmpty) {
      return const Center(
        child: Text(
          'No moods logged today',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: todayMoods.length,
      itemBuilder: (context, index) {
        final entry = todayMoods[todayMoods.length - 1 - index];
        return ListTile(
          dense: true,
          title: Text(
            entry.mood,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  void _showMoodCalendar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: MoodCalendarView(moodLogByDate: _moodLogByDate),
      ),
    );
  }

  Future<void> _addMoodEntry(String mood) async {
    final appState = context.read<AppState>();
    final unlocked = await appState.unlock(mood);

    if (unlocked && mounted) {
      Navigator.pop(context);
      Navigator.of(context).pushReplacementNamed('/vault');
      return;
    }

    final now = DateTime.now();
    final dateKey = _getDateKey(now);
    final entry = MoodEntry(mood: mood, timestamp: now);
    
    setState(() {
      if (_moodLogByDate[dateKey] == null) {
        _moodLogByDate[dateKey] = [];
      }
      _moodLogByDate[dateKey]!.add(entry);
    });
    await _saveMoodLog();
    _moodController.clear();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mood logged: $mood'),
          backgroundColor: Colors.blue[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : RefreshIndicator(
                  onRefresh: _fetchWeatherData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Weather',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _showMoodLogger,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.mood,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _showSettingsDialog,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.settings,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _locationName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(_weatherIcon, size: 100, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          '${_temperature?.round() ?? '--'}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Text(
                          _condition,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                          ),
                        ),
                        if (_weekForecast.isNotEmpty) ...[
                          Text(
                            'H:${_weekForecast[0].high.round()}° L:${_weekForecast[0].low.round()}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        if (_hourlyForecast.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HOURLY FORECAST',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _hourlyForecast.length > 12
                                        ? 12
                                        : _hourlyForecast.length,
                                    itemBuilder: (context, index) {
                                      final hour = _hourlyForecast[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              index == 0
                                                  ? 'Now'
                                                  : '${hour.hour.hour}:00',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Icon(
                                              hour.icon,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${hour.temp.round()}°',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
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
                        const SizedBox(height: 16),
                        if (_weekForecast.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '7-DAY FORECAST',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const Divider(color: Colors.white24),
                                ..._weekForecast.map(
                                  (day) => _buildDayRow(day),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDayRow(DailyForecast day) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final isToday =
        day.date.day == DateTime.now().day &&
        day.date.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              isToday ? 'Today' : weekdays[day.date.weekday - 1],
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Icon(day.icon, color: Colors.white, size: 24),
          const Spacer(),
          Text(
            '${day.low.round()}°',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Container(
            width: 80,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[300]!, Colors.orange[300]!],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${day.high.round()}°',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class MoodEntry {
  final String mood;
  final DateTime timestamp;

  MoodEntry({required this.mood, required this.timestamp});
  
  Map<String, dynamic> toJson() => {
    'mood': mood,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    mood: json['mood'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class MoodCalendarView extends StatefulWidget {
  final Map<String, List<MoodEntry>> moodLogByDate;
  
  const MoodCalendarView({super.key, required this.moodLogByDate});
  
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
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                }),
              ),
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
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
                .map((d) => Text(d, style: const TextStyle(color: Colors.white54)))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildCalendarGrid(),
        ),
        if (_selectedDate != null && widget.moodLogByDate[_selectedDate] != null)
          Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moods on $_selectedDate',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.moodLogByDate[_selectedDate]!.length,
                    itemBuilder: (context, index) {
                      final entry = widget.moodLogByDate[_selectedDate]![index];
                      return ListTile(
                        dense: true,
                        title: Text(entry.mood, style: const TextStyle(color: Colors.white)),
                        trailing: Text(
                          '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
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
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startingWeekday = firstDayOfMonth.weekday % 7;
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemCount: 42,
      itemBuilder: (context, index) {
        final dayNumber = index - startingWeekday + 1;
        if (dayNumber < 1 || dayNumber > lastDayOfMonth.day) {
          return const SizedBox();
        }
        
        final dateKey = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
        final hasMoods = widget.moodLogByDate[dateKey]?.isNotEmpty ?? false;
        final isSelected = _selectedDate == dateKey;
        final isToday = DateTime.now().year == _currentMonth.year && 
                        DateTime.now().month == _currentMonth.month && 
                        DateTime.now().day == dayNumber;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedDate = dateKey),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[600] : (hasMoods ? Colors.blue.withValues(alpha: 0.3) : null),
              borderRadius: BorderRadius.circular(8),
              border: isToday ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasMoods)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class HourlyForecast {
  final DateTime hour;
  final double temp;
  final IconData icon;

  HourlyForecast({required this.hour, required this.temp, required this.icon});
}

class DailyForecast {
  final DateTime date;
  final double high;
  final double low;
  final IconData icon;
  final String condition;

  DailyForecast({
    required this.date,
    required this.high,
    required this.low,
    required this.icon,
    required this.condition,
  });
}
