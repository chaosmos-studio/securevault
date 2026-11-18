import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/temp_files.dart';
import 'photo_viewer_screen.dart';
import 'viewer_chrome.dart';

/// Plays a video from a decrypted copy that is deleted when the screen closes.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videoData,
    required this.title,
    this.onDelete,
  });

  final Uint8List videoData;
  final String title;
  final Future<void> Function()? onDelete;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  File? _file;
  bool _chrome = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final file = await TempFiles.write(widget.title, widget.videoData);
      final controller = VideoPlayerController.file(file);
      _file = file;
      _controller = controller;
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _file?.delete().catchError((_) => _file!);
    super.dispose();
  }

  void _playPause() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    await context.read<AppState>().whileOutside(() => Share.shareXFiles([XFile(file.path)]));
  }

  Future<void> _openElsewhere() async {
    final file = _file;
    if (file == null) return;
    await context.read<AppState>().whileOutside(() => OpenFile.open(file.path));
  }

  Future<void> _saveToPhone() async {
    final message = await saveToDownloads(widget.title, widget.videoData);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'video')) return;
    await widget.onDelete?.call();
    if (mounted) Navigator.pop(context);
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _chrome = !_chrome),
            child: Center(
              child: _failed
                  ? const Icon(Icons.error_outline, color: Colors.white54, size: 48)
                  : ready
                      ? AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
                      : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          if (ready)
            Center(
              child: AnimatedOpacity(
                opacity: _chrome ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IconButton.filled(
                  iconSize: 44,
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  onPressed: _chrome ? _playPause : null,
                  icon: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white),
                ),
              ),
            ),
          ViewerChrome(
            visible: _chrome,
            title: widget.title,
            onMore: _openElsewhere,
            above: ready
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Text(_time(c.value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: VideoProgressIndicator(
                            c,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_time(c.value.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  )
                : null,
            actions: [
              ViewerAction(icon: Icons.ios_share_rounded, label: 'Share', onTap: _share),
              ViewerAction(icon: Icons.download_rounded, label: 'Save to phone', onTap: _saveToPhone),
              if (widget.onDelete != null)
                ViewerAction(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: _delete),
            ],
          ),
        ],
      ),
    );
  }
}
