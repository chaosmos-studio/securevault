import 'package:flutter/material.dart';
import '../../ui/vault_theme.dart';

class ViewerAction {
  const ViewerAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The bars over a photo or video: back and a title on top, actions below.
/// A tap on the picture hides them.
class ViewerChrome extends StatelessWidget {
  const ViewerChrome({
    super.key,
    required this.visible,
    required this.title,
    required this.actions,
    this.onMore,
    this.above,
  });

  final bool visible;
  final String title;
  final List<ViewerAction> actions;
  final VoidCallback? onMore;

  /// Shown just above the actions, such as a video's progress bar.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: kVaultFont, color: Colors.white);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Column(
          children: [
            Container(
              color: Colors.black54,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const BackButton(color: Colors.white),
                      Expanded(
                        child: Text(title, style: style.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                      if (onMore != null)
                        IconButton(
                          tooltip: 'Open in another app',
                          onPressed: onMore,
                          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            Container(
              color: Colors.black54,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    ?above,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final a in actions)
                            InkResponse(
                              onTap: a.onTap,
                              radius: 40,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(a.icon, color: Colors.white, size: 26),
                                    const SizedBox(height: 6),
                                    Text(a.label, style: style.copyWith(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
