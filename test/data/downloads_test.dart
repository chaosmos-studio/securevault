import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/services/downloads.dart';
import 'package:securevault/core/services/temp_files.dart';

import '../support/fakes.dart';

final _bytes = List.generate(5000, (i) => i * 7 % 256);

void main() {
  late Directory phone;
  late Directory downloads;

  setUp(() async {
    phone = await useFreshDevice();
    downloads = await Directory('${phone.path}/Download').create();
    Downloads.folder = downloads;
  });

  tearDown(() async {
    setWritable(downloads, true);
    await phone.delete(recursive: true);
  });

  test('saves into Downloads, numbering a name that is taken', () async {
    final first = await Downloads.save('IMG_1.jpg', _bytes);
    final second = await Downloads.save('IMG_1.jpg', _bytes);

    expect(first.inDownloads, isTrue);
    expect(first.file.path, '${downloads.path}/IMG_1.jpg');
    expect(second.file.path, '${downloads.path}/IMG_1 (1).jpg');
    expect(await second.file.readAsBytes(), _bytes);
  });

  test('saves into the app folder the vault empties on lock when Downloads is read-only',
      () async {
    setWritable(downloads, false);

    final copy = await Downloads.save('IMG_1.jpg', _bytes);

    expect(copy.inDownloads, isFalse);
    expect(copy.file.uri.pathSegments.last, 'IMG_1.jpg');
    expect(await copy.file.readAsBytes(), _bytes);
    expect(downloads.listSync(), isEmpty);
    await TempFiles.clear();
    expect(await copy.file.exists(), isFalse);
  });

  test('saves into the app folder on a phone with no Downloads folder', () async {
    Downloads.folder = Directory('${phone.path}/missing');

    final copy = await Downloads.save('IMG_1.jpg', _bytes);

    expect(copy.inDownloads, isFalse);
    expect(await copy.file.readAsBytes(), _bytes);
  });
}
