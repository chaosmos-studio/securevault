import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

class WeatherDisguise extends StatefulWidget {
  const WeatherDisguise({super.key});

  @override
  State<WeatherDisguise> createState() => _WeatherDisguiseState();
}

class _WeatherDisguiseState extends State<WeatherDisguise> {
  int _settingsTapCount = 0;
  final _secretCodeController = TextEditingController();
  final _random = Random();

  final List<WeatherDay> _weekForecast = [];

  @override
  void initState() {
    super.initState();
    _generateForecast();
  }

  @override
  void dispose() {
    _secretCodeController.dispose();
    super.dispose();
  }

  void _generateForecast() {
    final conditions = ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy', 'Stormy', 'Clear'];
    final icons = [Icons.wb_sunny, Icons.cloud, Icons.water_drop, Icons.cloud_queue, Icons.thunderstorm, Icons.nights_stay];
    
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
      final condIndex = _random.nextInt(conditions.length);
      _weekForecast.add(WeatherDay(
        date: day,
        condition: conditions[condIndex],
        icon: icons[condIndex],
        high: 15 + _random.nextInt(20),
        low: 5 + _random.nextInt(15),
      ));
    }
  }

  void _onSettingsTap() {
    _settingsTapCount++;
    if (_settingsTapCount >= 7) {
      _settingsTapCount = 0;
      _showSecretDialog();
    }
    Future.delayed(const Duration(seconds: 2), () {
      _settingsTapCount = 0;
    });
  }

  void _showSecretDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Options'),
        content: TextField(
          controller: _secretCodeController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter access code',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _tryUnlock(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _secretCodeController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _tryUnlock,
            child: const Text('Access'),
          ),
        ],
      ),
    );
  }

  Future<void> _tryUnlock() async {
    final code = _secretCodeController.text;
    _secretCodeController.clear();
    
    final appState = context.read<AppState>();
    final unlocked = await appState.unlock(code);
    
    if (mounted) {
      Navigator.pop(context);
      if (unlocked) {
        Navigator.of(context).pushReplacementNamed('/vault');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _weekForecast.isNotEmpty ? _weekForecast[0] : null;
    
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    GestureDetector(
                      onTap: _onSettingsTap,
                      child: const Icon(Icons.settings, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (today != null) ...[
                const SizedBox(height: 32),
                const Text(
                  'Current Location',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Icon(today.icon, size: 100, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  '${today.high}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  today.condition,
                  style: const TextStyle(color: Colors.white70, fontSize: 20),
                ),
                Text(
                  'H:${today.high}° L:${today.low}°',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
              const Spacer(),
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
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Divider(color: Colors.white24),
                    ..._weekForecast.map((day) => _buildDayRow(day)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayRow(WeatherDay day) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final isToday = day.date.day == DateTime.now().day;
    
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
            '${day.low}°',
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
            '${day.high}°',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class WeatherDay {
  final DateTime date;
  final String condition;
  final IconData icon;
  final int high;
  final int low;

  WeatherDay({
    required this.date,
    required this.condition,
    required this.icon,
    required this.high,
    required this.low,
  });
}
