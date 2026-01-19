import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class PhotoViewerScreen extends StatefulWidget {
  final Uint8List imageData;
  final String title;
  final VoidCallback? onDelete;

  const PhotoViewerScreen({
    super.key,
    required this.imageData,
    required this.title,
    this.onDelete,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  bool _showControls = true;

  Future<File> _getTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(tempPath);
    await file.writeAsBytes(widget.imageData);
    return file;
  }

  Future<void> _shareImage() async {
    try {
      final file = await _getTempFile();
      await Share.shareXFiles([XFile(file.path)], text: widget.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  Future<void> _openInExternalApp() async {
    try {
      final file = await _getTempFile();
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening: $e')));
      }
    }
  }

  Future<void> _exportToGallery() async {
    try {
      final downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      final fileName =
          'SecureVault_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(widget.imageData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting: $e')));
      }
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open in other app'),
              onTap: () {
                Navigator.pop(context);
                _openInExternalApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Export to Downloads'),
              onTap: () {
                Navigator.pop(context);
                _exportToGallery();
              },
            ),
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete from vault',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
          'Are you sure you want to delete this photo from the vault?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(widget.imageData, fit: BoxFit.contain),
              ),
            ),
            if (_showControls) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.black54,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
                  title: Text(widget.title, overflow: TextOverflow.ellipsis),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: _showOptionsMenu,
                      tooltip: 'More options',
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.share, 'Share', _shareImage),
                      _buildActionButton(
                        Icons.open_in_new,
                        'Open',
                        _openInExternalApp,
                      ),
                      _buildActionButton(
                        Icons.save_alt,
                        'Export',
                        _exportToGallery,
                      ),
                      if (widget.onDelete != null)
                        _buildActionButton(
                          Icons.delete,
                          'Delete',
                          _confirmDelete,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
