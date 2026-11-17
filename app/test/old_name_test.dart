import 'dart:io';

import 'package:arcvert/settings_store_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('the old folder is the same one under the ShiftDrop name', () {
    expect(
      oldNameFolder('/Users/a/Library/Application Support/io.github.navinkumar0007.arcvert'),
      '/Users/a/Library/Application Support/io.github.navinkumar0007.shiftdrop',
    );
    expect(
      oldNameFolder(p.join('/AppData', 'Roaming', 'Arcvert contributors', 'Arcvert')),
      p.join('/AppData', 'Roaming', 'ShiftDrop contributors', 'ShiftDrop'),
    );
    expect(oldNameFolder('/data/files'), isNull);
  });

  group('bringing over', () {
    late Directory root;
    late Directory now;
    late Directory before;

    setUp(() {
      root = Directory.systemTemp.createTempSync('rename');
      now = Directory(p.join(root.path, 'Arcvert contributors', 'Arcvert'));
      before = Directory(p.join(root.path, 'ShiftDrop contributors', 'ShiftDrop'))
        ..createSync(recursive: true);
      File(p.join(before.path, 'settings.json')).writeAsStringSync('{"welcomed": true}');
      File(p.join(before.path, 'history.json')).writeAsStringSync('[]');
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('settings and history come across, and the old ones stay', () async {
      await bringOverOldName(now);
      expect(File(p.join(now.path, 'settings.json')).readAsStringSync(), '{"welcomed": true}');
      expect(File(p.join(now.path, 'history.json')).readAsStringSync(), '[]');
      expect(File(p.join(before.path, 'settings.json')).existsSync(), isTrue);
    });

    test('never over settings Arcvert already has', () async {
      now.createSync(recursive: true);
      File(p.join(now.path, 'settings.json')).writeAsStringSync('{"theme": "dark"}');
      await bringOverOldName(now);
      expect(File(p.join(now.path, 'settings.json')).readAsStringSync(), '{"theme": "dark"}');
      expect(File(p.join(now.path, 'history.json')).existsSync(), isFalse);
    });

    test('nothing to bring is fine', () async {
      before.deleteSync(recursive: true);
      await bringOverOldName(now);
      expect(now.existsSync(), isFalse);
    });
  });
}
