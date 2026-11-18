import 'package:flutter/material.dart';
import '../services/app_dialogs_service.dart';

/// The overflow menu every disguise has. "Request a feature" also opens the
/// vault when its text is a vault password, which works for any password.
class DisguiseMenu extends StatelessWidget {
  const DisguiseMenu({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      tooltip: 'More options',
      onSelected: (value) {
        switch (value) {
          case 'about':
            AppDialogsService.showAboutUs(context);
          case 'contact':
            AppDialogsService.showContactUs(context);
          case 'feature':
            AppDialogsService.showRequestFeature(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'about', child: Text('About')),
        PopupMenuItem(value: 'contact', child: Text('Contact us')),
        PopupMenuItem(value: 'feature', child: Text('Request a feature')),
      ],
    );
  }
}
