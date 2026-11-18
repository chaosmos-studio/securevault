import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/temp_files.dart';
import '../../core/services/vault_service.dart';
import '../../ui/disguise_icon.dart';
import '../../ui/vault_theme.dart';
import 'media_tile.dart';
import 'notes_vault_screen.dart';
import 'photo_viewer_screen.dart';
import 'vault_settings_screen.dart';
import 'video_player_screen.dart';

/// The vault: photos, videos and notes, with the lock always one tap away.
class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  int _tab = 0;
  bool _working = false;
  final _picker = ImagePicker();
  final _selected = <String>{};
  final _notes = GlobalKey<NotesPaneState>();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  Future<void> _welcome() async {
    final state = context.read<AppState>();
    if (!state.welcomePending || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (context) => _WelcomeSheet(disguise: state.currentDisguise),
    );
    await state.dismissWelcome();
  }

  List<VaultItem> _items(Vault vault, VaultItemType type) =>
      vault.items.where((i) => i.type == type).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<ImageSource?> _askSource({required bool video}) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(video ? 'Choose videos' : 'Choose photos'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(video ? Icons.videocam_outlined : Icons.photo_camera_outlined),
                title: Text(video ? 'Record a video' : 'Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add() async {
    if (_tab == 2) {
      _notes.currentState?.create();
      return;
    }
    final video = _tab == 1;
    final source = await _askSource(video: video);
    if (source == null || !mounted) return;
    final state = context.read<AppState>();

    final picked = await state.whileOutside(() async {
      if (video) {
        final file = await _picker.pickVideo(source: source);
        return file == null ? <XFile>[] : [file];
      }
      if (source == ImageSource.gallery) return _picker.pickMultiImage();
      final file = await _picker.pickImage(source: source);
      return file == null ? <XFile>[] : [file];
    });
    if (picked.isEmpty || !mounted) return;

    setState(() => _working = true);
    try {
      for (final file in picked) {
        final vault = state.currentVault;
        final password = state.currentPassword;
        if (vault == null || password == null) return;
        final bytes = await file.readAsBytes();
        await VaultService.addItem(
          vault: vault,
          password: password,
          type: video ? VaultItemType.video : VaultItemType.photo,
          name: file.name,
          data: bytes,
          thumbnail: video ? null : await _thumbnail(bytes),
          key: state.currentKey,
        );
        await TempFiles.discard(file.path);
      }
      await state.refreshVault();
      if (mounted && source == ImageSource.gallery) {
        final n = picked.length;
        final what = video ? (n == 1 ? 'video' : 'videos') : (n == 1 ? 'photo' : 'photos');
        _toast('Added $n $what. The originals are still in your gallery.');
      }
    } catch (e) {
      _toast('Could not add that file');
    } finally {
      for (final file in picked) {
        await TempFiles.discard(file.path);
      }
      if (mounted) setState(() => _working = false);
    }
  }

  /// A small copy for the grid, so it never decodes full photos.
  Future<Uint8List> _thumbnail(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return data == null ? bytes : data.buffer.asUint8List();
    } catch (_) {
      return bytes;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _open(VaultItem item, List<VaultItem> siblings) async {
    if (_selecting) {
      _toggle(item.id);
      return;
    }
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;

    if (item.type == VaultItemType.photo) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          vault: vault,
          password: password,
          encryptionKey: state.currentKey,
          items: siblings,
          initialIndex: siblings.indexOf(item),
          onDelete: _deleteOne,
        ),
      ));
    } else {
      final data = await VaultService.getItemData(vault, password, item.id, key: state.currentKey);
      if (data == null || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          videoData: data,
          title: item.name,
          onDelete: () => _deleteOne(item),
        ),
      ));
    }
  }

  Future<void> _deleteOne(VaultItem item) async {
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;
    await VaultService.deleteItem(vault, password, item.id);
    await state.refreshVault();
  }

  Future<void> _shareSelected() async {
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;
    final files = <XFile>[];
    for (final id in _selected) {
      final item = vault.items.firstWhere((i) => i.id == id);
      final data = await VaultService.getItemData(vault, password, id, key: state.currentKey);
      if (data == null) continue;
      files.add(XFile((await TempFiles.write(item.name, data)).path));
    }
    if (files.isEmpty) return;
    await state.whileOutside(() => Share.shareXFiles(files));
    if (mounted) setState(_selected.clear);
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'item' : 'items'}?'),
        content: const Text('They are removed from the vault for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.vault.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = context.read<AppState>();
    final vault = state.currentVault;
    final password = state.currentPassword;
    if (vault == null || password == null) return;
    for (final id in _selected.toList()) {
      await VaultService.deleteItem(vault, password, id);
    }
    await state.refreshVault();
    if (mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.vault;
    final vault = state.currentVault;
    if (vault == null) return Scaffold(backgroundColor: c.ground);

    final photos = _items(vault, VaultItemType.photo);
    final videos = _items(vault, VaultItemType.video);
    final noteCount = vault.items.where((i) => i.type == VaultItemType.note).length;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        backgroundColor: c.ground,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _selecting
                  ? _SelectionBar(
                      count: _selected.length,
                      onClose: () => setState(_selected.clear),
                      onShare: _shareSelected,
                      onDelete: _deleteSelected,
                    )
                  : _Header(
                      title: state.currentVaultInfo?.name ?? 'Vault',
                      onSettings: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const VaultSettingsScreen())),
                      onLock: state.lock,
                    ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    _TabPill(label: 'Photos', count: photos.length, selected: _tab == 0, onTap: () => _switch(0)),
                    _TabPill(label: 'Videos', count: videos.length, selected: _tab == 1, onTap: () => _switch(1)),
                    _TabPill(label: 'Notes', count: noteCount, selected: _tab == 2, onTap: () => _switch(2)),
                  ],
                ),
              ),
              if (_working) LinearProgressIndicator(minHeight: 2, backgroundColor: c.ground),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    _grid(state, vault, photos, VaultItemType.photo),
                    _grid(state, vault, videos, VaultItemType.video),
                    NotesPane(key: _notes),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                heroTag: null,
                onPressed: _working ? null : _add,
                icon: const Icon(Icons.add),
                label: Text(switch (_tab) { 0 => 'Add photos', 1 => 'Add videos', _ => 'New note' }),
              ),
      ),
    );
  }

  void _switch(int tab) => setState(() {
        _tab = tab;
        _selected.clear();
      });

  Widget _grid(AppState state, Vault vault, List<VaultItem> items, VaultItemType type) {
    if (items.isEmpty) {
      return _EmptyPane(
        icon: type == VaultItemType.photo ? Icons.photo_outlined : Icons.movie_outlined,
        text: type == VaultItemType.photo ? 'No photos yet' : 'No videos yet',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 104),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaTile(
          key: ValueKey(item.id),
          item: item,
          vault: vault,
          password: state.currentPassword!,
          encryptionKey: state.currentKey,
          selected: _selected.contains(item.id),
          selecting: _selecting,
          onTap: () => _open(item, items),
          onLongPress: () => _toggle(item.id),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onSettings, required this.onLock});

  final String title;
  final VoidCallback onSettings;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onLock,
            icon: const Icon(Icons.lock_outline_rounded, size: 20),
            label: const Text('Lock'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              backgroundColor: c.ink,
              foregroundColor: c.ground,
              textStyle: const TextStyle(fontFamily: kVaultFont, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClose,
    required this.onShare,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Row(
        children: [
          IconButton(tooltip: 'Cancel', onPressed: onClose, icon: const Icon(Icons.close)),
          const SizedBox(width: 4),
          Expanded(
            child: Text('$count selected', style: Theme.of(context).textTheme.titleLarge),
          ),
          IconButton(tooltip: 'Share', onPressed: onShare, icon: const Icon(Icons.ios_share_rounded)),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: context.vault.danger),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final fg = selected ? c.ground : c.muted;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? c.ink : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (count > 0)
                    TextSpan(
                      text: '  $count',
                      style: TextStyle(color: fg.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                    ),
                ]),
                style: TextStyle(
                  fontFamily: kVaultFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? c.ground : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.muted),
            const SizedBox(height: 12),
            Text(text, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet({required this.disguise});

  final DisguiseType disguise;

  @override
  Widget build(BuildContext context) {
    final c = context.vault;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DisguiseIcon(disguise: null, size: 56),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.arrow_forward_rounded, color: c.muted),
                ),
                DisguiseIcon(disguise: disguise, size: 56),
              ],
            ),
            const SizedBox(height: 24),
            Text('Your vault is ready', style: text.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'When you leave, SecureVault becomes ${disguise.displayName} on your phone. '
              'Look for it in your apps.',
              style: text.bodyLarge!.copyWith(color: c.muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
