import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/vault_service.dart';
import '../../ui/vault_theme.dart';

/// One square of the photo or video grid. Decrypts its thumbnail on its own.
class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.vault,
    required this.password,
    required this.encryptionKey,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final VaultItem item;
  final Vault vault;
  final String password;
  final String? encryptionKey;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VaultService.getThumbnail(
      widget.vault,
      widget.password,
      widget.item,
      key: widget.encryptionKey,
    );
    if (mounted && data != null) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final isVideo = widget.item.type == VaultItemType.video;
    final thumb = _thumb;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: isVideo ? 'Video ${widget.item.name}' : 'Photo ${widget.item.name}',
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: isVideo ? const Color(0xFF1B1F1D) : c.raised),
            if (thumb != null)
              AnimatedPadding(
                duration: const Duration(milliseconds: 140),
                padding: EdgeInsets.all(widget.selected ? 10 : 0),
                child: Image.memory(
                  thumb,
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              )
            else if (isVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFC9CFCC), fontSize: 12),
                  ),
                ),
              ),
            if (isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
              ),
            if (widget.selecting)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected ? c.accent : Colors.black26,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: widget.selected
                      ? Icon(Icons.check, size: 15, color: c.onAccent)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
