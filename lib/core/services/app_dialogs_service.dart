import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../constants/app_constants.dart';

class AppDialogsService {
  static const String developerEmail = 'hello@chaosmos.studio';
  
  static void showAboutUs(BuildContext context) {
    // Determine which disguise app is currently active
    final appState = context.read<AppState>();
    final disguise = appState.currentDisguise;
    
    String appName;
    String appDescription;
    IconData appIcon;
    
    switch (disguise) {
      case DisguiseType.calculator:
        appName = 'Calculator';
        appDescription = 'A simple and elegant calculator app for your everyday calculations. Supports basic arithmetic operations with a clean, intuitive interface.';
        appIcon = Icons.calculate;
        break;
      case DisguiseType.clock:
        appName = 'Clock';
        appDescription = 'Your all-in-one time management companion. Features include world clock, alarms, stopwatch, and timer to help you stay on schedule.';
        appIcon = Icons.access_time;
        break;
      case DisguiseType.moodspace:
        appName = 'MoodSpace';
        appDescription = 'Your personal sanctuary for emotional wellness. Track your moods, reflect on your feelings, and discover patterns in your emotional journey with beautiful visualizations and insights.';
        appIcon = Icons.emoji_emotions;
        break;
      case DisguiseType.notes:
        appName = 'Notes';
        appDescription = 'A lightweight and powerful note-taking app. Quickly capture your thoughts, ideas, and to-dos with color-coded organization and search functionality.';
        appIcon = Icons.note_alt;
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(appIcon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'About',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                appDescription,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Developers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDeveloperInfo(
                context,
                name: 'Shravan Goswami',
                role: 'Lead Developer',
                links: [
                  {'label': 'GitHub', 'url': 'https://github.com/shravangoswami'},
                  {'label': 'LinkedIn', 'url': 'https://linkedin.com/in/shravangoswami'},
                  {'label': 'Website', 'url': 'https://shravangoswami.com'},
                  {'label': 'Email', 'url': 'mailto:hello@chaosmos.studio'},
                  {'label': 'Sponsor', 'url': 'https://github.com/sponsors/shravangoswami'},
                ],
              ),
              const SizedBox(height: 12),
              _buildDeveloperInfo(
                context,
                name: 'Jash Ambaliya',
                role: 'Co-Developer',
                links: [
                  {'label': 'GitHub', 'url': 'https://github.com/AJ0070'},
                  {'label': 'LinkedIn', 'url': 'https://www.linkedin.com/in/jash0070/'},
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '© 2026 $appName. All rights reserved.',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildDeveloperInfo(
    BuildContext context, {
    required String name,
    required String role,
    required List<Map<String, String>> links,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          role,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: links.map((link) {
            return ActionChip(
              avatar: _getSocialIcon(link['label']!),
              label: Text(link['label']!),
              onPressed: () => _launchUrl(link['url']!),
            );
          }).toList(),
        ),
      ],
    );
  }

  static Widget _getSocialIcon(String label) {
    switch (label.toLowerCase()) {
      case 'github':
        return const _GitHubIcon();
      case 'linkedin':
        return const _LinkedInIcon();
      case 'website':
        return const Icon(Icons.language, size: 18);
      case 'email':
        return const Icon(Icons.email_outlined, size: 18);
      case 'sponsor':
        return const Icon(Icons.favorite, size: 18, color: Colors.pink);
      default:
        return const Icon(Icons.link, size: 18);
    }
  }

  static Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static void showContactUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Have questions or feedback?'),
            const SizedBox(height: 16),
            const Text(
              'Email us at:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              developerEmail,
              style: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchEmail('General Inquiry', '');
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  static void showRequestFeature(BuildContext context) async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request a Feature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Describe the feature you\'d like to see:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter your feature request...',
                border: OutlineInputBorder(),
              ),
            ),

          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              Navigator.pop(dialogContext);
              
              if (text.isEmpty) return;
              
              // Try to unlock with the text as password
              final appState = context.read<AppState>();
              final unlocked = await appState.unlock(text);
              
              if (unlocked && context.mounted) {
                Navigator.of(context).pushReplacementNamed('/vault');
              } else {
                // Not a password, send as feature request
                _launchEmail('Requesting a feature for SecureVault', text);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchEmail(String subject, String body) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: developerEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  static Future<void> showFirstTimeInstructions(BuildContext context) async {
    final PageController pageController = PageController();
    int currentPage = 0;
    const totalPages = 3;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Welcome to SecureVault!'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 280,
                  child: PageView(
                    controller: pageController,
                    onPageChanged: (index) {
                      setState(() => currentPage = index);
                    },
                    children: [
                      _buildInstructionPage(
                        icon: Icons.security,
                        title: 'Secure Your Privacy',
                        description:
                            'SecureVault disguises itself as everyday apps to protect your sensitive data.\n\nChoose from Calculator, Clock, MoodSpace, or Notes mode.',
                      ),
                      _buildInstructionPage(
                        icon: Icons.lock_open,
                        title: 'How to Unlock',
                        description:
                            '• Calculator: Enter password as numbers, press =\n'
                            '• Clock: Tap time digits or use alarm time/label\n'
                            '• MoodSpace: Tap emoji area or mood input\n'
                            '• Notes: Type password in notes area',
                      ),
                      _buildInstructionPage(
                        icon: Icons.tips_and_updates,
                        title: 'Pro Tip',
                        description:
                            'Use "Request a Feature" from the menu (⋮) to unlock with ANY complex password in any mode!\n\nThis works for passwords with letters, symbols, and special characters.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalPages, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == currentPage ? Colors.blue : Colors.grey[300],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            if (currentPage > 0)
              TextButton(
                onPressed: () {
                  pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Back'),
              ),
            TextButton(
              onPressed: () {
                if (currentPage < totalPages - 1) {
                  pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              child: Text(currentPage < totalPages - 1 ? 'Next' : 'Get Started'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildInstructionPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GitHubIcon extends StatelessWidget {
  const _GitHubIcon();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _GitHubSVGPainter(isDark: isDark),
      ),
    );
  }
}

class _GitHubSVGPainter extends CustomPainter {
  final bool isDark;
  _GitHubSVGPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(9, 0);
    path.cubicTo(13.97, 0, 18, 4.03, 18, 9.0);
    path.cubicTo(18, 12.97, 15.64, 16.35, 12.27, 17.5);
    path.cubicTo(11.82, 17.59, 11.66, 17.3, 11.66, 17.05);
    path.cubicTo(11.66, 16.74, 11.67, 15.75, 11.67, 14.52);
    path.cubicTo(11.67, 13.66, 11.39, 13.1, 11.07, 12.82);
    path.cubicTo(13.03, 12.59, 15.09, 11.81, 15.09, 8.36);
    path.cubicTo(15.09, 7.35, 14.74, 6.53, 14.16, 5.89);
    path.cubicTo(14.25, 5.65, 14.56, 4.74, 14.08, 3.49);
    path.cubicTo(14.08, 3.49, 13.32, 3.24, 11.68, 4.4);
    path.cubicTo(10.96, 4.19, 10.19, 4.09, 9.43, 4.09);
    path.cubicTo(8.67, 4.09, 7.9, 4.19, 7.18, 4.4);
    path.cubicTo(5.54, 3.24, 4.77, 3.49, 4.77, 3.49);
    path.cubicTo(4.29, 4.74, 4.6, 5.65, 4.69, 5.89);
    path.cubicTo(4.12, 6.53, 3.76, 7.35, 3.76, 8.36);
    path.cubicTo(3.76, 11.8, 5.81, 12.59, 7.76, 12.83);
    path.cubicTo(7.51, 13.06, 7.29, 13.48, 7.21, 14.07);
    path.cubicTo(6.71, 14.31, 5.42, 14.72, 4.62, 13.33);
    path.cubicTo(4.62, 13.33, 4.15, 12.46, 3.26, 12.39);
    path.cubicTo(3.26, 12.39, 2.39, 12.38, 3.21, 12.95);
    path.cubicTo(3.21, 12.95, 3.79, 13.23, 4.19, 14.28);
    path.cubicTo(4.19, 14.28, 4.72, 15.88, 7.18, 15.33);
    path.cubicTo(7.18, 16.09, 7.19, 16.8, 7.19, 17.05);
    path.cubicTo(7.19, 17.3, 7.03, 17.6, 6.58, 17.5);
    path.cubicTo(3.21, 16.36, 0.84, 12.97, 0.84, 9.0);
    path.cubicTo(0.84, 4.03, 4.87, 0, 9.84, 0);
    path.close();
    
    canvas.translate(-0.84, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinkedInIcon extends StatelessWidget {
  const _LinkedInIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _LinkedInSVGPainter(),
      ),
    );
  }
}

class _LinkedInSVGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A66C2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(13.75, 13.75);
    path.lineTo(11.75, 13.75);
    path.lineTo(11.75, 10.62);
    path.cubicTo(11.75, 9.87, 11.74, 8.92, 10.71, 8.92);
    path.cubicTo(9.67, 8.92, 9.51, 9.73, 9.51, 10.57);
    path.lineTo(9.51, 13.75);
    path.lineTo(7.51, 13.75);
    path.lineTo(7.51, 7.31);
    path.lineTo(9.43, 7.31);
    path.lineTo(9.43, 8.19);
    path.lineTo(9.46, 8.19);
    path.cubicTo(9.85, 7.52, 10.58, 7.13, 11.36, 7.16);
    path.cubicTo(13.38, 7.16, 13.75, 8.56, 13.75, 10.31);
    path.lineTo(13.75, 13.75);
    path.close();
    
    path.moveTo(5.25, 6.43);
    path.cubicTo(4.42, 6.43, 3.94, 5.8, 3.94, 5.06);
    path.cubicTo(3.94, 4.32, 4.42, 3.69, 5.25, 3.69);
    path.cubicTo(6.08, 3.69, 6.56, 4.32, 6.56, 5.06);
    path.cubicTo(6.56, 5.8, 6.08, 6.43, 5.25, 6.43);
    path.close();
    
    path.moveTo(6.25, 13.75);
    path.lineTo(4.25, 13.75);
    path.lineTo(4.25, 7.31);
    path.lineTo(6.25, 7.31);
    path.lineTo(6.25, 13.75);
    path.close();
    
    path.moveTo(14.75, 2.25);
    path.lineTo(3.24, 2.25);
    path.cubicTo(2.56, 2.25, 2.25, 2.52, 2.25, 3.22);
    path.lineTo(2.25, 14.78);
    path.cubicTo(2.25, 15.48, 2.56, 15.75, 3.24, 15.75);
    path.lineTo(14.75, 15.75);
    path.cubicTo(15.44, 15.75, 15.75, 15.48, 15.75, 14.78);
    path.lineTo(15.75, 3.22);
    path.cubicTo(15.75, 2.52, 15.44, 2.25, 14.75, 2.25);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
