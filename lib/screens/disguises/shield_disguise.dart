import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

class ShieldDisguise extends StatefulWidget {
  const ShieldDisguise({super.key});

  @override
  State<ShieldDisguise> createState() => _ShieldDisguiseState();
}

class _ShieldDisguiseState extends State<ShieldDisguise> {
  String _inputPin = '';

  void _onDigitPress(String digit) async {
    setState(() {
      _inputPin += digit;
    });

    // Attempt unlock with current input
    // Note: AppState.unlock usually takes the full password.
    // If we want to check character by character we need a way to know length,
    // or just try every time. For simplicity, we try every time.
    final appState = context.read<AppState>();
    final unlocked = await appState.unlock(_inputPin);

    if (unlocked && mounted) {
      Navigator.of(context).pushReplacementNamed('/vault');
    } else {
      // If input is getting too long (e.g. > 20), clear it to prevent issues
      if (_inputPin.length > 20) {
        setState(() => _inputPin = '');
      }
    }
  }

  void _onBackspace() {
    if (_inputPin.isNotEmpty) {
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'SecureVault Locked',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            // Display dots for PIN length (optional, or just generic field)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _inputPin.length,
                (index) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: CircleAvatar(radius: 6, backgroundColor: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Expanded(child: _buildNumPad()),
          ],
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRow(['1', '2', '3']),
        _buildRow(['4', '5', '6']),
        _buildRow(['7', '8', '9']),
        _buildRow(['', '0', '⌫']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 80);

        return InkWell(
          onTap: () {
            if (key == '⌫') {
              _onBackspace();
            } else {
              _onDigitPress(key);
            }
          },
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: key == '⌫'
                ? const Icon(Icons.backspace_outlined, color: Colors.white)
                : Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }
}
