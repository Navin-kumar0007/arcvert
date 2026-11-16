import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shiftdrop/picked_file.dart';

PickedFile sample(String file, {String? name}) {
  final path = p.join(Directory.current.parent.path, 'test-files', file);
  final bytes = File(path).readAsBytesSync();
  return PickedFile(
    name: name ?? file,
    size: bytes.length,
    head: bytes.take(64).toList(),
    read: () async => Uint8List.fromList(bytes),
    path: path,
  );
}

void main() {
  final parts = [
    for (final n in ['01', '02', '03', '04']) sample('sample-parts5.part$n.rar'),
  ];

  test('the parts of a RAR become one file where its first was, holding the rest in order', () {
    final other = sample('sample-rar4.rar');
    final joined = joinArchiveParts([other, parts[2], parts[0], parts[3], parts[1]]);
    expect(joined.map((f) => f.name), ['sample-rar4.rar', 'sample-parts5.rar']);
    final archive = joined.last;
    expect(archive.path, parts.first.path);
    expect(archive.head, parts.first.head);
    expect(archive.moreParts.map((f) => f.name), [
      'sample-parts5.part02.rar',
      'sample-parts5.part03.rar',
      'sample-parts5.part04.rar',
    ]);
    expect(archive.size, parts.fold<int>(0, (total, f) => total + f.size));
    expect(archive.missingPart, isNull);
  });

  test('a gap is noted, for the job to name it', () {
    final joined = joinArchiveParts([parts[0], parts[1], parts[3]]).single;
    expect(joined.missingPart, 'sample-parts5.part03.rar');
  });

  test('joining twice changes nothing', () {
    final once = joinArchiveParts(parts);
    final twice = joinArchiveParts(once);
    expect(twice.single, same(once.single));
  });

  test('only real RARs join: a 7z named like a part stays itself', () {
    final fake = sample('sample-lzma2.7z', name: 'sample-parts5.part05.rar');
    final joined = joinArchiveParts([...parts, fake]);
    expect(joined, hasLength(2));
    expect(joined.last, same(fake));
    expect(joined.first.moreParts, hasLength(3));
  });

  test('one part alone stays as it is', () {
    expect(joinArchiveParts([parts[1]]).single, same(parts[1]));
  });
}
