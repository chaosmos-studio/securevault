import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Uint8List videoData;
  final String title;
  final VoidCallback? onDelete;

  const VideoPlayerScreen({
    super.key,
    required this.videoData,
    required this.title,
    this.onDelete,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  File? _tempFile;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _tempFile = File(tempPath);
      await _tempFile!.writeAsBytes(widget.videoData);

      _controller = VideoPlayerController.file(_tempFile!)
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
          _controller!.play();
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading video: $e')));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tempFile?.delete();
    super.dispose();
  }

  Future<void> _shareVideo() async {
    if (_tempFile == null) return;
    try {
      await Share.shareXFiles([XFile(_tempFile!.path)], text: widget.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  Future<void> _openInExternalApp() async {
    if (_tempFile == null) return;
    try {
      await OpenFile.open(_tempFile!.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening: $e')));
      }
    }
  }

  Future<void> _exportToDownloads() async {
    try {
      final downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      final fileName =
          'SecureVault_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(widget.videoData);

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
                _shareVideo();
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
                _exportToDownloads();
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
        title: const Text('Delete Video'),
        content: const Text(
          'Are you sure you want to delete this video from the vault?',
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
              child: _isInitialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const CircularProgressIndicator(),
            ),
            if (_showControls && _isInitialized) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.black54,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    widget.title, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
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
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildVideoControls(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.share, 'Share', _shareVideo),
                          _buildActionButton(
                            Icons.open_in_new,
                            'Open',
                            _openInExternalApp,
                          ),
                          _buildActionButton(
                            Icons.save_alt,
                            'Export',
                            _exportToDownloads,
                          ),
                          if (widget.onDelete != null)
                            _buildActionButton(
                              Icons.delete,
                              'Delete',
                              _confirmDelete,
                            ),
                        ],
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

  Widget _buildVideoControls() {
    if (_controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_controller!.value.position),
            style: const TextStyle(color: Colors.white),
          ),
          const Text(' / ', style: TextStyle(color: Colors.white)),
          Text(
            _formatDuration(_controller!.value.duration),
            style: const TextStyle(color: Colors.white),
          ),
        ],
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
