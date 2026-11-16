import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

List<int> head(String name) =>
    File(p.join('..', 'test-files', name)).readAsBytesSync().take(64).toList();

void main() {
  group('what a RAR\'s first header says', () {
    test('whole archives', () {
      expect(rarSplitOf(head('sample-rar4.rar')), RarSplit.whole);
      expect(rarSplitOf(head('sample-rar5.rar')), RarSplit.whole);
    });

    test('first and later parts, in RAR 4 and RAR 5', () {
      expect(rarSplitOf(head('sample-parts4.part1.rar')), RarSplit.first);
      expect(rarSplitOf(head('sample-parts4.part3.rar')), RarSplit.later);
      expect(rarSplitOf(head('sample-parts5.part01.rar')), RarSplit.first);
      expect(rarSplitOf(head('sample-parts5.part04.rar')), RarSplit.later);
    });

    test('anything else, or too little to tell', () {
      expect(rarSplitOf(head('sample-lzma2.7z')), isNull);
      expect(rarSplitOf(head('sample-parts5.part01.rar').take(10).toList()), isNull);
      expect(rarSplitOf(const []), isNull);
    });
  });

  group('which files are parts of one archive', () {
    test('partN names, put in order whatever order they came in', () {
      final sets = findPartSets([
        'notes.txt',
        'Photos.part3.rar',
        'Photos.part1.rar',
        'photos.PART2.rar',
      ]);
      expect(sets.single.name, 'Photos.rar');
      expect(sets.single.order, [2, 3, 1]);
      expect(sets.single.missing, isNull);
    });

    test('the older .rar, .r00, .r01 names', () {
      final set = findPartSets(['a.r01', 'a.rar', 'a.r00']).single;
      expect(set.order, [1, 2, 0]);
      expect(set.name, 'a.rar');
    });

    test('a missing part is named as its set names them', () {
      expect(
        findPartSets(['x.part01.rar', 'x.part02.rar', 'x.part04.rar']).single.missing,
        'x.part03.rar',
      );
      expect(findPartSets(['x.part2.rar', 'x.part3.rar']).single.missing, 'x.part1.rar');
      expect(findPartSets(['old.r00', 'old.r01']).single.missing, 'old.rar');
      expect(findPartSets(['old.rar', 'old.r01']).single.missing, 'old.r00');
    });

    test('a part on its own, a plain RAR and other archives stay as they are', () {
      expect(findPartSets(['x.part1.rar']), isEmpty);
      expect(findPartSets(['one.rar', 'two.rar', 'three.zip']), isEmpty);
    });

    test('two sets at once, and a copy of a part counted once', () {
      final sets = findPartSets([
        'b.part1.rar',
        'a.part2.rar',
        'a.part1.rar',
        'b.part2.rar',
        'b.part2.rar',
      ]);
      expect(sets.map((s) => s.name), ['b.rar', 'a.rar']);
      expect(sets.first.order, [0, 3]);
      expect(sets.last.order, [2, 1]);
    });
  });

  group('the parts beside a file', () {
    final folder = ['x.part2.rar', 'x.part1.rar', 'y.rar', 'x.part3.rar', 'x.txt'];

    test('from any one of them, the whole set in order', () {
      expect(partsBeside('x.part2.rar', folder)!.parts, [
        'x.part1.rar',
        'x.part2.rar',
        'x.part3.rar',
      ]);
    });

    test('with what is missing', () {
      final found = partsBeside('x.part1.rar', ['x.part1.rar', 'x.part3.rar']);
      expect(found!.missing, 'x.part2.rar');
      expect(found.name, 'x.rar');
    });

    test('none for a file that is not a part there', () {
      expect(partsBeside('y.rar', folder), isNull);
      expect(partsBeside('z.part1.rar', ['z.part1.rar']), isNull);
    });
  });
}
