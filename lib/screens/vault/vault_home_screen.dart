import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/vault_service.dart';
import 'vault_settings_screen.dart';
import 'photo_viewer_screen.dart';
import 'video_player_screen.dart';
import 'notes_vault_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final appState = context.read<AppState>();
      if (appState.shouldAutoLock()) {
        appState.lock();
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _addPhoto() async {
    final appState = context.read<AppState>();
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage();
        if (images.isEmpty) return;

        setState(() => _isLoading = true);
        final vault = appState.currentVault;
        final password = appState.currentPassword;

        if (vault == null || password == null) return;

        final addedFiles = <String>[];
        for (final image in images) {
          final bytes = await image.readAsBytes();
          final thumbnail = await _generateThumbnail(bytes);

          await VaultService.addItem(
            vault: vault,
            password: password,
            type: VaultItemType.photo,
            name: image.name,
            data: bytes,
            thumbnail: thumbnail,
          );
          addedFiles.add(image.path);
        }

        await appState.refreshVault();

        if (mounted && addedFiles.isNotEmpty) {
          _showDeleteOriginalDialog(addedFiles, 'photo');
        }
      } else {
        final XFile? image = await _picker.pickImage(source: source);
        if (image == null) return;

        setState(() => _isLoading = true);
        final vault = appState.currentVault;
        final password = appState.currentPassword;

        if (vault == null || password == null) return;

        final bytes = await image.readAsBytes();
        final thumbnail = await _generateThumbnail(bytes);

        await VaultService.addItem(
          vault: vault,
          password: password,
          type: VaultItemType.photo,
          name: image.name,
          data: bytes,
          thumbnail: thumbnail,
        );

        await appState.refreshVault();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding photo: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVideo() async {
    final appState = context.read<AppState>();
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      final XFile? video = await _picker.pickVideo(source: source);
      if (video == null) return;

      setState(() => _isLoading = true);
      final vault = appState.currentVault;
      final password = appState.currentPassword;

      if (vault == null || password == null) return;

      final bytes = await video.readAsBytes();

      await VaultService.addItem(
        vault: vault,
        password: password,
        type: VaultItemType.video,
        name: video.name,
        data: bytes,
      );

      await appState.refreshVault();

      if (mounted && source == ImageSource.gallery) {
        _showDeleteOriginalDialog([video.path], 'video');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding video: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDeleteOriginalDialog(List<String> filePaths, String type) {
    final count = filePaths.length;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Original $type${count > 1 ? 's' : ''}?'),
        content: Text(
          count > 1
              ? '$count ${type}s have been securely stored in your vault. Would you like to delete the originals from your device gallery?'
              : 'The $type has been securely stored in your vault. Would you like to delete the original from your device gallery?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(count > 1 ? 'Keep Originals' : 'Keep Original'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteFromGallery(filePaths, type);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              count > 1 ? 'Delete Originals' : 'Delete Original',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFromGallery(List<String> filePaths, String type) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Permission denied to access gallery')),
        );
        return;
      }

      final assetType = type == 'photo' ? RequestType.image : RequestType.video;
      final albums = await PhotoManager.getAssetPathList(type: assetType);

      final idsToDelete = <String>[];

      for (final filePath in filePaths) {
        final file = File(filePath);
        if (!await file.exists()) continue;
        
        final fileStats = await file.stat();
        final fileSize = fileStats.size;
        
        for (final album in albums) {
          final assets = await album.getAssetListRange(start: 0, end: 1000);
          for (final asset in assets) {
            final assetFile = await asset.file;
            if (assetFile != null) {
              if (assetFile.path == filePath) {
                idsToDelete.add(asset.id);
                break;
              }
              final assetSize = await assetFile.length();
              if (assetSize == fileSize) {
                idsToDelete.add(asset.id);
                break;
              }
            }
          }
          if (idsToDelete.length == filePaths.length) break;
        }
      }

      if (idsToDelete.isNotEmpty) {
        final result = await PhotoManager.editor.deleteWithIds(idsToDelete);
        if (result.isNotEmpty) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('${result.length} original $type${result.length > 1 ? 's' : ''} deleted from gallery')),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Could not delete original ${type}s')),
          );
        }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Original $type${filePaths.length > 1 ? 's' : ''} not found in gallery')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error deleting original: $e')),
      );
    }
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _generateThumbnail(Uint8List imageBytes) async {
    return imageBytes;
  }

  void _lockVault() {
    final appState = context.read<AppState>();
    appState.lock();
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  Future<void> _shareSelectedItems() async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;
    
    if (vault == null || password == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final tempDir = await getTemporaryDirectory();
    final files = <XFile>[];

    for (final itemId in _selectedItems) {
      final item = vault.items.firstWhere((i) => i.id == itemId);
      final data = await VaultService.getItemData(vault, password, itemId);
      if (data != null) {
        final ext = item.type == VaultItemType.photo ? 'jpg' : 'mp4';
        final file = File('${tempDir.path}/${item.name}.$ext');
        await file.writeAsBytes(data);
        files.add(XFile(file.path));
      }
    }

    if (files.isNotEmpty) {
      await Share.shareXFiles(files, text: 'Shared from SecureVault');
    }
    
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });
    
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Shared ${files.length} items')),
    );
  }

  Future<void> _deleteSelectedItems() async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;
    
    if (vault == null || password == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items'),
        content: Text('Delete ${_selectedItems.length} selected items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final itemId in _selectedItems) {
      await VaultService.deleteItem(vault, password, itemId);
    }
    
    await appState.refreshVault();
    
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final vault = appState.currentVault;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (vault == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              ),
              title: Text('${_selectedItems.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _selectedItems.isNotEmpty ? _shareSelectedItems : null,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedItems.isNotEmpty ? _deleteSelectedItems : null,
                  tooltip: 'Delete',
                ),
              ],
            )
          : AppBar(
              title: const Text('Vault'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VaultSettingsScreen()),
                    );
                  },
                  tooltip: 'Settings',
                ),
                IconButton(
                  icon: const Icon(Icons.lock),
                  onPressed: _lockVault,
                  tooltip: 'Lock Vault',
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMediaGrid(vault, VaultItemType.photo),
                _buildMediaGrid(vault, VaultItemType.video),
                const NotesVaultScreen(),
              ],
            ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.grey[850]!, Colors.grey[900]!]
                : [Colors.white, Colors.grey[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark 
                ? Colors.grey[700]!.withValues(alpha: 0.3)
                : Colors.grey[200]!.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.photo_outlined, Icons.photo, 'Photos', colorScheme),
              _buildNavItem(1, Icons.videocam_outlined, Icons.videocam, 'Videos', colorScheme),
              _buildNavItem(2, Icons.note_outlined, Icons.note, 'Notes', colorScheme),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedIndex < 2 && !_isSelectionMode
          ? FloatingActionButton(
              onPressed: _selectedIndex == 0 ? _addPhoto : _addVideo,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label, ColorScheme colorScheme) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected 
                  ? colorScheme.onPrimaryContainer 
                  : colorScheme.onSurface.withValues(alpha: 0.6),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(Vault vault, VaultItemType type) {
    final items = vault.items.where((item) => item.type == type).toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == VaultItemType.photo
                  ? Icons.photo_library
                  : Icons.video_library,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == VaultItemType.photo ? 'No photos yet' : 'No videos yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: type == VaultItemType.photo ? _addPhoto : _addVideo,
              icon: const Icon(Icons.add),
              label: Text(
                type == VaultItemType.photo ? 'Add Photo' : 'Add Video',
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMediaTile(item, type);
      },
    );
  }

  Widget _buildMediaTile(VaultItem item, VaultItemType type) {
    final isSelected = _selectedItems.contains(item.id);
    
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleItemSelection(item.id);
        } else {
          _openMedia(item);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedItems.add(item.id);
          });
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<Uint8List?>(
              future: _loadThumbnail(item),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }
                return Center(
                  child: Icon(
                    type == VaultItemType.photo ? Icons.photo : Icons.videocam,
                    color: Colors.grey[500],
                  ),
                );
              },
            ),
          ),
          if (type == VaultItemType.video)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
              ),
            ),
          if (_isSelectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.white.withValues(alpha: 0.8),
                  border: Border.all(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<Uint8List?> _loadThumbnail(VaultItem item) async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return null;

    return await VaultService.getThumbnail(vault, password, item);
  }

  void _openMedia(VaultItem item) async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return;

    final data = await VaultService.getItemData(vault, password, item.id);
    if (data == null || !mounted) return;

    if (item.type == VaultItemType.photo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoViewerScreen(
            imageData: data,
            title: item.name,
            onDelete: () => _deleteItem(item),
          ),
        ),
      );
    } else if (item.type == VaultItemType.video) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoData: data,
            title: item.name,
            onDelete: () => _deleteItem(item),
          ),
        ),
      );
    }
  }

  Future<void> _deleteItem(VaultItem item) async {
    final appState = context.read<AppState>();
    final vault = appState.currentVault;
    final password = appState.currentPassword;

    if (vault == null || password == null) return;

    try {
      await VaultService.deleteItem(vault, password, item.id);
      await appState.refreshVault();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }
}
