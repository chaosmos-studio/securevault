import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/services/temp_files.dart';

import '../support/fakes.dart';

void main() {
  late Directory phone;
  late Directory temp;

  setUp(() async {
    phone = await useFreshDevice();
    temp = await Directory('${phone.path}/tmp').create();
  });

  tearDown(() => phone.delete(recursive: true));

  Future<File> leave(String path) async {
    final file = File('${temp.path}/$path');
    await file.parent.create(recursive: true);
    return file.writeAsBytes([1, 2, 3]);
  }

  test('emptying the temporary folder removes every plain copy left in it', () async {
    await leave('0b6e2c4a-91d3-4c55-a7f0-2f1d6c0e8b13/IMG_0412.jpg');
    await leave('image_picker4417630121.jpg');
    await leave('file_picker/1731900000000/backup.svb');
    await leave('share_plus/IMG_0412.jpg');
    await TempFiles.write('IMG_0412.jpg', [1, 2, 3]);

    await TempFiles.clear();

    expect(temp.listSync(), isEmpty);
  });

  test('discarding a picked copy removes it and the folder the picker made for it', () async {
    final copy = await leave('0b6e2c4a-91d3-4c55-a7f0-2f1d6c0e8b13/IMG_0412.jpg');

    await TempFiles.discard(copy.path);

    expect(temp.listSync(), isEmpty);
  });

  test('discarding never touches a file outside the temporary folder', () async {
    final original = await File('${phone.path}/documents/IMG_0412.jpg').create(recursive: true);

    await TempFiles.discard(original.path);

    expect(await original.exists(), isTrue);
  });
}
