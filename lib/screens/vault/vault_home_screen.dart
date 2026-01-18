import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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

class _VaultHomeScreenState extends State<VaultHomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding photo: $e')),
        );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding video: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final vault = appState.currentVault;

    if (vault == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: _lockVault,
            tooltip: 'Lock Vault',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VaultSettingsScreen()),
            ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo), label: 'Photos'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Videos'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
        ],
      ),
      floatingActionButton: _selectedIndex < 2
          ? FloatingActionButton(
              onPressed: _selectedIndex == 0 ? _addPhoto : _addVideo,
              child: const Icon(Icons.add),
            )
          : null,
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
              type == VaultItemType.photo ? Icons.photo_library : Icons.video_library,
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
              label: Text(type == VaultItemType.photo ? 'Add Photo' : 'Add Video'),
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
    return GestureDetector(
      onTap: () => _openMedia(item),
      onLongPress: () => _showDeleteDialog(item),
      child: Container(
        color: Colors.grey[300],
        child: FutureBuilder<Uint8List?>(
          future: _loadThumbnail(item),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              );
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
          builder: (context) => PhotoViewerScreen(imageData: data, title: item.name),
        ),
      );
    } else if (item.type == VaultItemType.video) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoData: data, title: item.name),
        ),
      );
    }
  }

  void _showDeleteDialog(VaultItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItem(item);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }
}
