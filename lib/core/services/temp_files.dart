import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// The app's temporary folder, which holds plain copies of private files: the
/// decrypted copies handed to other apps (to share, open or play), and the
/// copies the photo picker, the file picker and the share sheet make there.
/// It is emptied whenever the vault locks or the app starts, and each picked
/// file is discarded as soon as it is in the vault.
class TempFiles {
  static Future<Directory> folder() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/open');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> create(String name) async {
    final dir = await folder();
    final safe = name.replaceAll(RegExp(r'[\\/]'), '_');
    // A folder per copy keeps the original file name for the other app.
    final own = await Directory('${dir.path}/${DateTime.now().microsecondsSinceEpoch}')
        .create();
    return File('${own.path}/$safe').create();
  }

  static Future<File> write(String name, List<int> bytes) async =>
      (await create(name)).writeAsBytes(bytes, flush: true);

  /// Deletes a picker's copy at [path], and the folder the picker made for it
  /// once that is empty. Files outside the temporary folder are never touched,
  /// so a picker that hands back an original leaves it alone.
  static Future<void> discard(String path) async {
    try {
      final temp = (await getTemporaryDirectory()).absolute.path;
      final file = File(path).absolute;
      if (!file.path.startsWith('$temp${Platform.pathSeparator}')) return;
      if (await file.exists()) await file.delete();
      final parent = file.parent;
      if (parent.path != temp && await parent.list().isEmpty) await parent.delete();
    } on FileSystemException {
      // Already gone or busy: the next lock empties the folder.
    }
  }

  static Future<void> clear() async {
    try {
      final temp = await getTemporaryDirectory();
      await for (final entity in temp.list()) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          // Busy: the next lock tries again.
        }
      }
    } on FileSystemException {
      // No temporary folder yet: nothing to clear.
    }
  }
}
