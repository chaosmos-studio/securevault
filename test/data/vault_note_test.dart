import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/models/vault_note.dart';

void main() {
  test('reads back notes in any language exactly as written', () {
    final note = VaultNote(
      id: '1',
      title: 'नमस्ते',
      content: 'Chai ☕ at 5, ¡olé!',
      updatedAt: DateTime(2026, 11, 18),
      colorIndex: 3,
      isPinned: true,
    );

    final back = VaultNote.decode(note.encode());

    expect(back.title, 'नमस्ते');
    expect(back.content, 'Chai ☕ at 5, ¡olé!');
    expect(back.colorIndex, 3);
    expect(back.isPinned, isTrue);
  });

  test('reads notes saved by 1.0.3, which wrote UTF-8 JSON', () {
    final saved = Uint8List.fromList(utf8.encode(json.encode({
      'id': '1767225600000',
      'title': 'Locker 14',
      'content': 'Code 2207. Chai ☕',
      'updatedAt': '2026-01-01T10:00:00.000',
      'colorIndex': 3,
      'isPinned': true,
    })));

    expect(VaultNote.decode(saved).content, 'Code 2207. Chai ☕');
    // How 1.0.3 read the same bytes back.
    expect(String.fromCharCodes(saved).contains('Chai ☕'), isFalse);
  });
}
