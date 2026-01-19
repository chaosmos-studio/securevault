import 'package:flutter/material.dart';
import '../services/app_dialogs_service.dart';

class DisguiseMenu extends StatelessWidget {
  final Color? iconColor;
  
  const DisguiseMenu({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor ?? Colors.black),
      onSelected: (value) {
        switch (value) {
          case 'about':
            AppDialogsService.showAboutUs(context);
            break;
          case 'contact':
            AppDialogsService.showContactUs(context);
            break;
          case 'feature':
            AppDialogsService.showRequestFeature(context);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'about',
          child: Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 12),
              Text('About Us'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'contact',
          child: Row(
            children: [
              Icon(Icons.email_outlined),
              SizedBox(width: 12),
              Text('Contact Us'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'feature',
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline),
              SizedBox(width: 12),
              Text('Request a Feature'),
            ],
          ),
        ),
      ],
    );
  }
}
