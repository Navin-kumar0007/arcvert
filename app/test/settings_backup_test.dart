import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radial_core/radial_core.dart';
import 'package:arcvert/app_settings.dart';
import 'package:arcvert/settings_backup.dart';
import 'package:arcvert/settings_screen.dart';
import 'package:arcvert/words.dart';

const _college = MyFit(
  id: 'my-fit-a1',
  name: 'College form',
  form: FormTarget(width: 200, height: 230, minBytes: 20480, maxBytes: 50000),
);
const _bank = MyFit(
  id: 'my-fit-b2',
  name: 'Bank signature',
  form: FormTarget(width: 140, height: 60, maxBytes: 20000, signature: true),
);

final _mine = AppSettings(
  welcomed: true,
  theme: 'dark',
  language: 'hi',
  showPreviews: false,
  learnOrder: true,
  uses: const {'image-rotate': 4, 'my-fit-a1': 2},
  triggerKey: 'control',
  checkForUpdates: false,
  resultsFolder: '/Users/someone/Results',
  lastUpdateCheck: DateTime.utc(2026, 11, 16),
  whatsNewSeen: '0.16.0',
  myFits: const [_college, _bank],
);

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

SettingsBackup _backupOf(AppSettings settings) =>
    readSettingsBackup(_bytes(exportSettings(settings, appVersion: '0.17.0')));

void main() {
  group('the file', () {
    test('says what it is, and holds only what can move to another device', () {
      final text = exportSettings(_mine, appVersion: '0.17.0', now: DateTime(2026, 11, 17));
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['arcvertSettings'], 1);
      expect(json['appVersion'], '0.17.0');
      expect(json['exported'], '2026-11-17');
      final settings = json['settings'] as Map<String, Object?>;
      expect(
        settings.keys,
        unorderedEquals([
          'checkForUpdates',
          'language',
          'theme',
          'showPreviews',
          'learnOrder',
          'uses',
          'triggerKey',
          'myFits',
        ]),
      );
      // Nothing that names a folder on this computer.
      expect(text, isNot(contains('/Users/')));
    });

    test('is named for the day', () {
      expect(backupFileName(now: DateTime(2026, 11, 17)), 'Arcvert settings 2026-11-17.json');
    });

    test('reads back as it was saved', () {
      final backup = _backupOf(_mine);
      expect(backup.settings.theme, 'dark');
      expect(backup.settings.myFits, [_college, _bank]);
      expect(backup.has('resultsFolder'), isFalse);
      expect(backup.has('theme'), isTrue);
    });

    test('anything else is refused', () {
      for (final text in [
        '',
        'not json',
        '[1, 2]',
        '{"theme": "dark"}',
        '{"arcvertSettings": "1", "settings": {}}',
        '{"arcvertSettings": 1}',
        '{"arcvertSettings": 1, "settings": []}',
      ]) {
        expect(() => readSettingsBackup(_bytes(text)), throwsFormatException, reason: text);
      }
      expect(() => readSettingsBackup(Uint8List.fromList([0xff, 0xfe, 0])), throwsFormatException);
      expect(() => readSettingsBackup(Uint8List(maxBackupBytes + 1)), throwsFormatException);
    });

    test('damaged settings inside read as the defaults', () {
      final backup = readSettingsBackup(
        _bytes('{"arcvertSettings": 1, "settings": {"theme": "purple", "myFits": "x"}}'),
      );
      expect(backup.settings.theme, 'system');
      expect(backup.settings.myFits, isEmpty);
    });
  });

  group('bringing it in', () {
    test('choices become the file\'s, and this device keeps its own', () {
      const here = AppSettings(welcomed: true, resultsFolder: '/here', whatsNewSeen: '0.17.0');
      final result = importSettings(here, _backupOf(_mine)).result;
      expect(result.theme, 'dark');
      expect(result.language, 'hi');
      expect(result.showPreviews, isFalse);
      expect(result.triggerKey, 'control');
      expect(result.checkForUpdates, isFalse);
      expect(result.myFits, [_college, _bank]);
      expect(result.resultsFolder, '/here');
      expect(result.whatsNewSeen, '0.17.0');
      expect(result.welcomed, isTrue);
    });

    test('a choice the file lacks is left as it is', () {
      const here = AppSettings(theme: 'light', language: 'en');
      final backup = readSettingsBackup(
        _bytes('{"arcvertSettings": 1, "settings": {"showPreviews": false}}'),
      );
      final result = importSettings(here, backup).result;
      expect(result.theme, 'light');
      expect(result.language, 'en');
      expect(result.showPreviews, isFalse);
    });

    test('slices join, one with the same name replacing its match and keeping its id', () {
      const here = AppSettings(
        myFits: [
          MyFit(id: 'my-fit-here', name: 'COLLEGE FORM', form: FormTarget(maxBytes: 9000)),
          MyFit(id: 'my-fit-other', name: 'Exam', form: FormTarget()),
        ],
        uses: {'my-fit-here': 7, 'image-rotate': 9},
      );
      final import = importSettings(here, _backupOf(_mine));
      expect(import.slicesAdded, 1);
      expect(import.slicesChanged, 1);
      expect(import.slicesLeftOut, 0);
      final fits = import.result.myFits;
      expect(fits.map((fit) => fit.name), ['College form', 'Exam', 'Bank signature']);
      expect(fits.first.id, 'my-fit-here');
      expect(fits.first.form.maxBytes, 50000);
      // Learned counts keep the larger.
      expect(import.result.uses['image-rotate'], 9);
      expect(import.result.uses['my-fit-a1'], 2);
    });

    test('the same file twice changes nothing more', () {
      final once = importSettings(const AppSettings(), _backupOf(_mine));
      final twice = importSettings(once.result, _backupOf(_mine));
      expect(twice.slicesAdded, 0);
      expect(twice.slicesChanged, 0);
      expect(twice.result.myFits, once.result.myFits);
    });

    test('only as many slices as there is room for', () {
      final full = AppSettings(
        myFits: [
          for (var i = 0; i < MyFit.most; i++)
            MyFit(id: 'my-fit-n$i', name: 'Form $i', form: const FormTarget()),
        ],
      );
      final import = importSettings(full, _backupOf(_mine));
      expect(import.slicesAdded, 0);
      expect(import.slicesLeftOut, 2);
      expect(import.result.myFits, hasLength(MyFit.most));
    });
  });

  group('in Settings', () {
    late SettingsStore store;
    late List<(String, String)> saved;

    Future<void> show(WidgetTester tester, {Uint8List? picked, bool save = true}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      saved = [];
      await tester.pumpWidget(
        SettingsScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: Words.localizationsDelegates,
            home: SettingsScreen(
              desktop: false,
              chooseFolder: () async => null,
              loadPresets: () async => const [],
              saveBackup: (name, bytes) async {
                saved.add((name, utf8.decode(bytes)));
                return save;
              },
              pickBackup: () async => picked,
            ),
          ),
        ),
      );
    }

    testWidgets('saving makes the file and says so', (tester) async {
      store = SettingsStore(_mine, write: (_) async {});
      await show(tester);
      await tester.tap(find.text('Save settings to a file'));
      await tester.pump();
      expect(saved.single.$1, startsWith('Arcvert settings '));
      final back = readSettingsBackup(_bytes(saved.single.$2));
      expect(back.settings.myFits, [_college, _bank]);
      expect(find.text('Settings saved.'), findsOneWidget);
    });

    testWidgets('cancelled, nothing is said', (tester) async {
      store = SettingsStore(_mine, write: (_) async {});
      await show(tester, save: false);
      await tester.tap(find.text('Save settings to a file'));
      await tester.pump();
      expect(find.text('Settings saved.'), findsNothing);
    });

    testWidgets('a file is brought in after saying what changes', (tester) async {
      store = SettingsStore(const AppSettings(), write: (_) async {});
      await show(tester, picked: _bytes(exportSettings(_mine, appVersion: '0.17.0')));
      await tester.tap(find.text('Bring in settings from a file'));
      await tester.pumpAndSettle();
      expect(find.text('Bring in these settings?'), findsOneWidget);
      expect(find.text('Slices: 2 new, 0 changed.'), findsOneWidget);
      // Nothing yet.
      expect(store.value.myFits, isEmpty);
      await tester.tap(find.text('Bring in'));
      await tester.pumpAndSettle();
      expect(store.value.myFits, [_college, _bank]);
      expect(store.value.theme, 'dark');
    });

    testWidgets('cancelled, nothing changes', (tester) async {
      store = SettingsStore(const AppSettings(), write: (_) async {});
      await show(tester, picked: _bytes(exportSettings(_mine, appVersion: '0.17.0')));
      await tester.tap(find.text('Bring in settings from a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.value.myFits, isEmpty);
      expect(store.value.theme, 'system');
    });

    testWidgets('another kind of file is refused in plain words', (tester) async {
      store = SettingsStore(const AppSettings(), write: (_) async {});
      await show(tester, picked: _bytes('{"hello": "world"}'));
      await tester.tap(find.text('Bring in settings from a file'));
      await tester.pump();
      expect(find.text("This isn't an Arcvert settings file."), findsOneWidget);
      expect(find.text('Bring in these settings?'), findsNothing);
    });
  });
}
