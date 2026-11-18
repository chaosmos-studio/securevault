import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/painting.dart';

/// A note inside a vault, stored as one encrypted item of JSON.
class VaultNote {
  VaultNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.colorIndex = 0,
    this.isPinned = false,
  });

  String id;
  String title;
  String content;
  DateTime updatedAt;
  int colorIndex;
  bool isPinned;

  /// Colour tags by index, as saved since 1.0. Index 0 is no colour.
  static const List<Color> tags = [
    Color(0x00000000),
    Color(0xFFE5776E),
    Color(0xFFEFA445),
    Color(0xFFE9CF4B),
    Color(0xFF8CC56B),
    Color(0xFF4FB8A4),
    Color(0xFF6CB4D2),
    Color(0xFF6F93D9),
    Color(0xFFA788D8),
    Color(0xFFE38DB5),
    Color(0xFFB39A7A),
    Color(0xFF9AA0A6),
  ];

  Color? get tag => colorIndex == 0 ? null : tags[colorIndex % tags.length];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'colorIndex': colorIndex,
        'isPinned': isPinned,
      };

  factory VaultNote.fromJson(Map<String, dynamic> json) => VaultNote(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        colorIndex: json['colorIndex'] as int? ?? 0,
        isPinned: json['isPinned'] as bool? ?? false,
      );

  Uint8List encode() => Uint8List.fromList(utf8.encode(json.encode(toJson())));

  /// Notes have always been saved as UTF-8. Versions up to 1.0.3 read them
  /// back byte by byte, which garbled anything beyond plain English letters.
  static VaultNote decode(Uint8List bytes) => VaultNote.fromJson(
      json.decode(utf8.decode(bytes, allowMalformed: true)) as Map<String, dynamic>);
}
