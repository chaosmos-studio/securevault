import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Decrypted copies handed to other apps (to share, open or play) live in one
/// folder, emptied whenever the vault locks or the app starts.
class TempFiles {
  static Future<Directory> folder() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/open');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> write(String name, List<int> bytes) async {
    final dir = await folder();
    final safe = name.replaceAll(RegExp(r'[\\/]'), '_');
    // A folder per copy keeps the original file name for the other app.
    final own = await Directory('${dir.path}/${DateTime.now().microsecondsSinceEpoch}')
        .create();
    return File('${own.path}/$safe').writeAsBytes(bytes, flush: true);
  }

  static Future<void> clear() async {
    try {
      final temp = await getTemporaryDirectory();
      final dir = Directory('${temp.path}/open');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Nothing to clear, or the folder is busy: the next lock tries again.
    }
  }
}
