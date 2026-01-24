import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/vault_service.dart';
import '../../core/constants/app_constants.dart';

class CachedMediaTile extends StatefulWidget {
  final VaultItem item;
  final Vault vault;
  final String password;
  final String? encryptionKey;
  final bool isSelected;
  final bool isSelectionMode;
  final Function(String) onToggleSelection;
  final Function(VaultItem) onOpen;
  final Function(String) onLongPress;

  const CachedMediaTile({
    super.key,
    required this.item,
    required this.vault,
    required this.password,
    this.encryptionKey,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onOpen,
    required this.onLongPress,
  });

  @override
  State<CachedMediaTile> createState() => _CachedMediaTileState();
}

class _CachedMediaTileState extends State<CachedMediaTile> {
  Uint8List? _thumbnailData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(CachedMediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (_thumbnailData != null) return;
    
    if (mounted) setState(() => _isLoading = true);
    
    final data = await VaultService.getThumbnail(
      widget.vault, 
      widget.password, 
      widget.item,
      key: widget.encryptionKey,
    );
    
    if (mounted) {
      setState(() {
        _thumbnailData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          widget.onToggleSelection(widget.item.id);
        } else {
          widget.onOpen(widget.item);
        }
      },
      onLongPress: () => widget.onLongPress(widget.item.id),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _thumbnailData != null
                    ? Image.memory(
                        _thumbnailData!, 
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Center(
                        child: Icon(
                          widget.item.type == VaultItemType.photo
                              ? Icons.photo
                              : Icons.videocam,
                          color: Colors.grey[500],
                        ),
                      ),
          ),
          if (widget.item.type == VaultItemType.video)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          if (widget.isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white.withValues(alpha: 0.8),
                  border: Border.all(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          if (widget.isSelected)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
