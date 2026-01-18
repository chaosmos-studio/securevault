import 'dart:typed_data';
import 'package:flutter/material.dart';

class PhotoViewerScreen extends StatelessWidget {
  final Uint8List imageData;
  final String title;

  const PhotoViewerScreen({
    super.key,
    required this.imageData,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            imageData,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
