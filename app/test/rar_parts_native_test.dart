// The desktop finding a RAR's other parts beside the one chosen, with the Mac's own libarchive.
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:radial_core/radial_core.dart';
import 'package:shiftdrop/convert_native.dart';
import 'package:shiftdrop/picked_file.dart';

void main() {
  // Windows and Linux are left to core's libarchive test, against the copy Windows ships.
  if (!Platform.isMacOS) return;
  late Directory folder;
  final numbers = ['01', '02', '03', '04'];

  setUp(() {
    folder = Directory.systemTemp.createTempSync('parts');
    for (final n in numbers) {
      File(p.join(Directory.current.parent.path, 'test-files', 'sample-parts5.part$n.rar'))
          .copySync(p.join(folder.path, 'trip.part$n.rar'));
    }
    File(p.join(folder.path, 'notes.txt')).writeAsStringSync('not a part');
  });
  tearDown(() => folder.deleteSync(recursive: true));

  PickedFile chosen(String n) {
    final path = p.join(folder.path, 'trip.part$n.rar');
    final bytes = File(path).readAsBytesSync();
    return PickedFile(
      name: p.basename(path),
      size: bytes.length,
      head: bytes.take(64).toList(),
      read: () async => bytes,
      path: path,
    );
  }

  test('the first part alone finds the rest beside it', () async {
    final zip = ZipDecoder().decodeBytes(await unpackArchive(chosen('01')));
    expect(zip.files, hasLength(9));
  });

  test('so does a later one', () async {
    final zip = ZipDecoder().decodeBytes(await unpackArchive(chosen('03')));
    expect(zip.findFile('elf-Linux-ARMv7-ls')!.size, 90808);
  });

  test('a part gone from the folder is named', () async {
    File(p.join(folder.path, 'trip.part02.rar')).deleteSync();
    await expectLater(
      unpackArchive(chosen('01')),
      throwsA(
        isA<EngineFailed>()
            .having((e) => e.key, 'key', 'partMissing')
            .having((e) => e.message, 'message', contains('trip.part02.rar')),
      ),
    );
  });

  test('with no others beside it, it fails as one part of several', () async {
    for (final n in numbers.skip(1)) {
      File(p.join(folder.path, 'trip.part$n.rar')).deleteSync();
    }
    await expectLater(
      unpackArchive(chosen('01')),
      throwsA(isA<EngineFailed>().having((e) => e.key, 'key', 'damagedOrPart')),
    );
  });
}
