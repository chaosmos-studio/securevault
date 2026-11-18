import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/downloads.dart';
import '../../core/services/temp_files.dart';
import '../../core/services/vault_service.dart';
import 'viewer_chrome.dart';

/// Full-screen photos, swiped left and right, pinched to zoom.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.vault,
    required this.password,
    required this.encryptionKey,
    required this.items,
    required this.initialIndex,
    required this.onDelete,
  });

  final Vault vault;
  final String password;
  final String? encryptionKey;
  final List<VaultItem> items;
  final int initialIndex;
  final Future<void> Function(VaultItem) onDelete;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final List<VaultItem> _items = [...widget.items];
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final _cache = <String, Future<Uint8List?>>{};
  bool _chrome = true;

  @override
  void dispose() {
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<Uint8List?> _bytes(VaultItem item) => _cache.putIfAbsent(
        item.id,
        () => VaultService.getItemData(widget.vault, widget.password, item.id,
            key: widget.encryptionKey),
      );

  VaultItem get _current => _items[_index];

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    SystemChrome.setEnabledSystemUIMode(
        _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  }

  Future<void> _share() async {
    final data = await _bytes(_current);
    if (data == null || !mounted) return;
    final file = await TempFiles.write(_current.name, data);
    if (!mounted) return;
    await context.read<AppState>().whileOutside(() => Share.shareXFiles([XFile(file.path)]));
  }

  Future<void> _openElsewhere() async {
    final data = await _bytes(_current);
    if (data == null || !mounted) return;
    final file = await TempFiles.write(_current.name, data);
    if (!mounted) return;
    await context.read<AppState>().whileOutside(() => OpenFile.open(file.path));
  }

  Future<void> _saveToPhone() async {
    final data = await _bytes(_current);
    if (data == null || !mounted) return;
    await saveToPhone(context, _current.name, data);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'photo')) return;
    final item = _current;
    await widget.onDelete(item);
    if (!mounted) return;
    if (_items.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.removeAt(_index);
      _index = _index.clamp(0, _items.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: _toggleChrome,
              child: FutureBuilder<Uint8List?>(
                future: _bytes(_items[i]),
                builder: (context, snap) {
                  final data = snap.data;
                  if (data == null) {
                    return snap.connectionState == ConnectionState.done
                        ? const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48))
                        : const SizedBox.expand();
                  }
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: SizedBox.expand(
                      child: Image.memory(data, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  );
                },
              ),
            ),
          ),
          ViewerChrome(
            visible: _chrome,
            title: '${_index + 1} of ${_items.length}',
            onMore: _openElsewhere,
            actions: [
              ViewerAction(icon: Icons.ios_share_rounded, label: 'Share', onTap: _share),
              ViewerAction(icon: Icons.download_rounded, label: 'Save to phone', onTap: _saveToPhone),
              ViewerAction(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: _delete),
            ],
          ),
        ],
      ),
    );
  }
}

/// Writes a copy outside the vault: into Downloads, or on phones where
/// Downloads can't be written, through the share sheet.
Future<void> saveToPhone(BuildContext context, String name, Uint8List data) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final copy = await Downloads.save(name, data);
    if (copy.inDownloads) {
      messenger.showSnackBar(const SnackBar(content: Text('Saved to Downloads')));
    } else {
      await state.whileOutside(() => Share.shareXFiles([XFile(copy.file.path)]));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not save a copy')));
  }
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete this $what?'),
      content: const Text('It is removed from the vault for good.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
