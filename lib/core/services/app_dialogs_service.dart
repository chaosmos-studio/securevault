import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../providers/app_state.dart';
import '../../screens/disguises/disguise_screen.dart';
import '../../ui/text_prompt.dart';

/// The dialogs behind each disguise's menu. They speak as the disguise, so
/// nothing here names the vault.
class AppDialogsService {
  static const String developerEmail = AppConstants.contactEmail;

  static void showAboutUs(BuildContext context) {
    final disguise = context.read<AppState>().currentDisguise;
    final description = switch (disguise) {
      DisguiseType.calculator => 'A simple calculator for everyday sums.',
      DisguiseType.clock => 'Alarms, a timer and a stopwatch.',
      DisguiseType.moodspace => 'A daily check-in for how you feel.',
      DisguiseType.notes => 'Quick notes, kept on your phone.',
    };

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(disguise.icon, size: 36),
        title: Text(disguise.displayName),
        content: Text('$description\n\nVersion ${AppConstants.version}',
            textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static void showContactUs(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact us'),
        content: const SelectableText(developerEmail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchEmail('Hello', '');
            },
            child: const Text('Send email'),
          ),
        ],
      ),
    );
  }

  static Future<void> showRequestFeature(BuildContext context) async {
    final text = await askText(
      context,
      title: 'Request a feature',
      hint: 'What would you like to see?',
      confirm: 'Send',
      maxLines: 4,
      border: true,
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;

    if (!await tryVaultCode(context, text)) {
      _launchEmail('Feature request', text.trim());
    }
  }

  static Future<void> _launchEmail(String subject, String body) async {
    // Mail apps show "+" for spaces, so spaces are written as %20.
    final uri = Uri(
      scheme: 'mailto',
      path: developerEmail,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
