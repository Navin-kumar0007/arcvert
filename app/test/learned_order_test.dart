import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:radial_core/radial_core.dart';
import 'package:shiftdrop/app_settings.dart';
import 'package:shiftdrop/conversion.dart';
import 'package:shiftdrop/converter_screen.dart';
import 'package:shiftdrop/words.dart';

void main() {
  group('settings keep the counts', () {
    test('they are saved and read back', () {
      final settings = const AppSettings().usedOnce('image-rotate').usedOnce('image-rotate');
      final back = AppSettings.decode(settings.encode());
      expect(back.uses, {'image-rotate': 2});
      expect(back.learnOrder, isTrue);
    });

    test('damaged counts read as none, and learning stays on unless turned off', () {
      expect(AppSettings.decode('{"uses": {"a": "x", "b": -1, "c": 3}}').uses, {'c': 3});
      expect(AppSettings.decode('{"uses": [1, 2]}').uses, isEmpty);
      expect(AppSettings.decode('{"learnOrder": false}').learnOrder, isFalse);
    });

    test('the trigger key is Shift unless Control was chosen', () {
      expect(const AppSettings().triggerKey, 'shift');
      final control = const AppSettings().copyWith(triggerKey: 'control');
      expect(AppSettings.decode(control.encode()).triggerKey, 'control');
      expect(AppSettings.decode('{"triggerKey": "fn"}').triggerKey, 'shift');
    });

    test('the list never grows past its limit', () {
      var settings = AppSettings(
        uses: {for (var i = 0; i < AppSettings.mostUses; i++) 'action-$i': 1},
      );
      settings = settings.usedOnce('one-more');
      expect(settings.uses.containsKey('one-more'), isFalse);
      expect(settings.usedOnce('action-1').uses['action-1'], 2);
    });
  });

  group('on the screen', () {
    late List<String> ran;
    late SettingsStore store;

    Future<void> pump(WidgetTester tester, AppSettings settings) async {
      ran = [];
      store = SettingsStore(settings, write: (_) async {});
      final bytes = img.encodeJpg(img.Image(width: 32, height: 24));
      await tester.pumpWidget(
        SettingsScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: Words.localizationsDelegates,
            home: ConverterScreen(
              keepWorking: (_) async {},
              pickFiles: () async => [
                PickedFile(name: 'a.jpg', size: bytes.length, head: bytes, read: () async => bytes),
              ],
              saveFile: (_) async => const SavedAs(),
              mediaAvailable: false,
              historyReader: () async => null,
              historyWriter: (_) async {},
              sharedFiles: () => const Stream.empty(),
              converter: (action, files, onProgress, options) {
                ran.add(action.id);
                return runPortable(action, files, options: options);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose files'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Tools'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> runFirstSlice(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    }

    final usual = actionsFor(const [FileKind.jpg], ActionMode.tools).first.id;

    testWidgets('a habit takes the first slot, and each use is counted', (tester) async {
      await pump(tester, const AppSettings(welcomed: true, uses: {'image-flip': 4}));
      await runFirstSlice(tester);
      expect(ran, ['image-flip']);
      expect(store.value.uses['image-flip'], 5);
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('turned off, the usual order stays and nothing is counted', (tester) async {
      await pump(
        tester,
        const AppSettings(welcomed: true, learnOrder: false, uses: {'image-flip': 4}),
      );
      await runFirstSlice(tester);
      expect(ran, [usual]);
      expect(store.value.uses['image-flip'], 4);
      expect(store.value.uses.containsKey(usual), isFalse);
      await tester.pump(const Duration(minutes: 1));
    });
  });
}
