import 'dart:io';

import 'package:flutter/foundation.dart';

import 'temp_files.dart';

/// A copy taken out of the vault, and whether it landed in Downloads.
typedef SavedCopy = ({File file, bool inDownloads});

/// Puts copies in the phone's Downloads folder.
///
/// Android 11 and later let any app add files there. Android 7 to 10 need a
/// storage permission the app does not hold, so there a copy goes to
/// [TempFiles] instead, for the caller to hand to the share sheet.
class Downloads {
  @visibleForTesting
  static Directory folder = Directory('/storage/emulated/0/Download');

  /// A new, empty file for [name], numbered if Downloads already has one.
  static Future<SavedCopy> create(String name) async {
    try {
      return (file: await (await _free(name)).create(exclusive: true), inDownloads: true);
    } on FileSystemException {
      return (file: await TempFiles.create(name), inDownloads: false);
    }
  }

  static Future<SavedCopy> save(String name, List<int> data) async {
    final copy = await create(name);
    await copy.file.writeAsBytes(data, flush: true);
    return copy;
  }

  static Future<File> _free(String name) async {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var file = File('${folder.path}/$name');
    for (var n = 1; await file.exists(); n++) {
      file = File('${folder.path}/$stem ($n)$ext');
    }
    return file;
  }
}
