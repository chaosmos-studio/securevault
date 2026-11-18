import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points path_provider at folders inside [root], so vault files land in a temp dir.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => '${root.path}/documents';

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/support';
}

/// Fresh, empty storage for one test: secure storage, preferences and files.
Future<Directory> useFreshDevice() async {
  final root = await Directory.systemTemp.createTemp('securevault_test_');
  PathProviderPlatform.instance = FakePathProvider(root);
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  return root;
}

/// Makes [dir] read-only, as Downloads is on Android 7 to 10 without a storage
/// permission, or writable again.
void setWritable(Directory dir, bool writable) {
  Process.runSync('chmod', [writable ? 'u+w' : 'a-w', dir.path]);
}

/// Restores a device snapshot written by [snapshotDevice].
Future<Directory> useDeviceSnapshot(Directory snapshot) async {
  final root = await Directory.systemTemp.createTemp('securevault_test_');
  await copyDirectory(Directory('${snapshot.path}/documents'),
      Directory('${root.path}/documents'));
  PathProviderPlatform.instance = FakePathProvider(root);

  final secure = (json.decode(
          await File('${snapshot.path}/secure_storage.json').readAsString())
      as Map<String, dynamic>)
      .cast<String, String>();
  FlutterSecureStorage.setMockInitialValues(Map<String, String>.of(secure));

  final prefs = json.decode(
          await File('${snapshot.path}/shared_preferences.json').readAsString())
      as Map<String, dynamic>;
  SharedPreferences.setMockInitialValues(prefs.cast<String, Object>());
  return root;
}

/// Writes secure storage, preferences and the documents folder to [out].
Future<void> snapshotDevice(Directory root, Directory out) async {
  await out.create(recursive: true);
  final secure = await const FlutterSecureStorage().readAll();
  await File('${out.path}/secure_storage.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(_sorted(secure)));

  final prefs = await SharedPreferences.getInstance();
  final values = <String, Object>{
    for (final key in prefs.getKeys()) key: prefs.get(key)!,
  };
  await File('${out.path}/shared_preferences.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(_sorted(values)));

  await copyDirectory(
      Directory('${root.path}/documents'), Directory('${out.path}/documents'));
}

Future<void> copyDirectory(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entity in from.list(recursive: true)) {
    final relative = entity.path.substring(from.path.length + 1);
    if (entity is Directory) {
      await Directory('${to.path}/$relative').create(recursive: true);
    } else if (entity is File) {
      await File('${to.path}/$relative').parent.create(recursive: true);
      await entity.copy('${to.path}/$relative');
    }
  }
}

/// Every file under [dir] with its bytes, keyed by relative path.
Future<Map<String, List<int>>> readTree(Directory dir) async {
  final files = <String, List<int>>{};
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      files[entity.path.substring(dir.path.length + 1)] =
          await entity.readAsBytes();
    }
  }
  return files;
}

Map<String, T> _sorted<T>(Map<String, T> map) =>
    Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
