import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:radial_core/radial_core.dart';
import 'package:arcvert/app_settings.dart';
import 'package:arcvert/conversion.dart';
import 'package:arcvert/converter_screen.dart';
import 'package:arcvert/option_screens.dart';
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

List<MyFit> _many(int count) => [
  for (var i = 0; i < count; i++)
    MyFit(id: 'my-fit-n$i', name: 'Form $i', form: const FormTarget(maxBytes: 50000)),
];

Widget _app(Widget home, [SettingsStore? store]) {
  final app = MaterialApp(localizationsDelegates: Words.localizationsDelegates, home: home);
  return store == null ? app : SettingsScope(store: store, child: app);
}

void main() {
  group('kept in the settings', () {
    test('come back in the order made', () {
      final settings = const AppSettings().keepMyFit(_college).keepMyFit(_bank);
      expect(AppSettings.decode(settings.encode()).myFits, [_college, _bank]);
      expect(const AppSettings().encode(), isNot(contains('myFits')));
    });

    test('a damaged one is left out and the rest kept', () {
      final text = AppSettings(myFits: const [_college])
          .encode()
          .replaceFirst('"myFits":[', '"myFits":[{"id":"image-form","name":"x"},"nonsense",');
      final twice = AppSettings(myFits: const [_college])
          .encode()
          .replaceFirst('"myFits":[', '"myFits":[{"id":"my-fit-a1","name":"Twice"},');
      expect(AppSettings.decode(text).myFits, [_college]);
      expect(AppSettings.decode(twice).myFits.single.name, 'Twice');
      expect(AppSettings.decode('{"myFits": {"a": 1}}').myFits, isEmpty);
    });

    test('never more than the most there can be', () {
      final full = AppSettings(myFits: _many(MyFit.most));
      expect(full.keepMyFit(_college).myFits, hasLength(MyFit.most));
      final text = full.encode().replaceFirst(
        '"myFits":[',
        '"myFits":[{"id":"my-fit-x","name":"X"},',
      );
      expect(AppSettings.decode(text).myFits, hasLength(MyFit.most));
    });

    test('a changed one keeps its place', () {
      const settings = AppSettings(myFits: [_college, _bank]);
      final renamed = _college.copyWith(name: 'University form');
      expect(settings.keepMyFit(renamed).myFits, [renamed, _bank]);
      // Full, a change still goes in.
      final full = AppSettings(myFits: [_college, ..._many(MyFit.most - 1)]);
      expect(full.keepMyFit(renamed).myFits.first, renamed);
    });

    test('deleting one forgets its count in the learned order too', () {
      final settings = const AppSettings(
        myFits: [_college, _bank],
        uses: {'my-fit-a1': 5, 'image-rotate': 2},
      ).forgetMyFit(_college.id);
      expect(settings.myFits, [_bank]);
      expect(settings.uses, {'image-rotate': 2});
    });
  });

  group('in the menus', () {
    test('come first, for pictures only, where the engine can run them', () {
      final jpg = availableActions(
        const [FileKind.jpg],
        ActionMode.convert,
        mediaAvailable: false,
        myFits: const [_college, _bank],
      );
      expect(jpg.take(2), [_college.action, _bank.action]);
      expect(
        availableActions(
          const [FileKind.pdf],
          ActionMode.convert,
          mediaAvailable: false,
          myFits: const [_college],
        ),
        isNot(contains(_college.action)),
      );
      expect(
        availableActions(
          const [FileKind.jpg],
          ActionMode.tools,
          mediaAvailable: false,
          myFits: const [_college],
        ),
        isNot(contains(_college.action)),
      );
      // HEIC needs the platform to decode it first.
      const heic = [FileKind.heic];
      expect(
        availableActions(heic, ActionMode.convert, mediaAvailable: false, myFits: [_college]),
        isNot(contains(_college.action)),
      );
      expect(
        availableActions(heic, ActionMode.convert, mediaAvailable: true, myFits: [_college]),
        contains(_college.action),
      );
    });

    testWidgets('a slice runs as Form photo with its sizes, named after it', (tester) async {
      final store = SettingsStore(
        const AppSettings(welcomed: true, myFits: [_college]),
        write: (_) async {},
      );
      final ran = <(String, ActionOptions)>[];
      final bytes = img.encodeJpg(img.Image(width: 320, height: 240));
      await tester.pumpWidget(
        _app(
          ConverterScreen(
            keepWorking: (_) async {},
            pickFiles: () async => [
              PickedFile(name: 'me.jpg', size: bytes.length, head: bytes, read: () async => bytes),
            ],
            saveFile: (_) async => const SavedAs(),
            mediaAvailable: false,
            historyReader: () async => null,
            historyWriter: (_) async {},
            sharedFiles: () => const Stream.empty(),
            converter: (action, files, onProgress, options) {
              ran.add((action.id, options));
              return runPortable(action, files, options: options);
            },
          ),
          store,
        ),
      );
      await tester.tap(find.text('Choose files'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Make it fit'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('College form'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // The work runs for real, finishing between frames.
      for (var i = 0; i < 20 && find.textContaining('(college form)').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Nothing was asked: no Form photo dialog.
      expect(find.byType(FormDialog), findsNothing);
      final (id, options) = ran.last;
      expect(id, 'image-form');
      expect(options.form!.width, 200);
      expect(options.form!.maxBytes, 50000);
      expect(options.nameSuffix, 'college form');
      expect(find.textContaining('me (college form).jpg'), findsWidgets);
      // Its size was tried when the slice was highlighted, and the job took that result.
      expect(ran, hasLength(1));
      expect(store.value.uses[_college.id], 1);
      await tester.pump(const Duration(minutes: 1));
    });
  });

  group('kept from Form photo', () {
    Future<FormTarget?> ask(
      WidgetTester tester,
      Future<void> Function() fill, {
      List<MyFit> mine = const [],
      required List<MyFit> kept,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FormTarget? chosen;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showDialog<FormTarget>(
                  context: context,
                  builder: (_) => FormDialog(myFits: mine, onKeep: kept.add),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await fill();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      return chosen;
    }

    Finder box(String label) => find.widgetWithText(TextField, label);
    Finder keep() => find.byKey(const ValueKey('keep as slice'));

    testWidgets('off, nothing is kept', (tester) async {
      final kept = <MyFit>[];
      final form = await ask(tester, () async {
        await tester.enterText(box('At most (KB)'), '50');
      }, kept: kept);
      expect(form!.maxBytes, 50000);
      expect(kept, isEmpty);
    });

    testWidgets('on, the sizes are kept under the name given, and the job still runs', (
      tester,
    ) async {
      final kept = <MyFit>[];
      final form = await ask(tester, () async {
        await tester.enterText(box('Width (pixels)'), '200');
        await tester.enterText(box('Height (pixels)'), '230');
        await tester.enterText(box('At most (KB)'), '50');
        await tester.tap(keep());
        await tester.pump();
        await tester.enterText(box('Slice name'), '  College   form ');
      }, kept: kept);
      expect(form!.width, 200);
      expect(kept.single.name, 'College form');
      expect(isMyFitId(kept.single.id), isTrue);
      expect(kept.single.form.width, 200);
      expect(kept.single.form.maxBytes, 50000);
    });

    testWidgets('a name is needed', (tester) async {
      final kept = <MyFit>[];
      final form = await ask(tester, () async {
        await tester.tap(keep());
        await tester.pump();
      }, kept: kept);
      expect(form, isNull);
      expect(find.text('Give it a name.'), findsOneWidget);
      await tester.enterText(box('Slice name'), 'Exam');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(kept.single.name, 'Exam');
    });

    testWidgets('a name already taken is refused, whatever its capitals', (tester) async {
      final kept = <MyFit>[];
      final form = await ask(
        tester,
        () async {
          await tester.tap(keep());
          await tester.pump();
          await tester.enterText(box('Slice name'), 'college FORM');
        },
        mine: const [_college],
        kept: kept,
      );
      expect(form, isNull);
      expect(find.text('You already have a slice called college FORM.'), findsOneWidget);
      expect(kept, isEmpty);
    });

    testWidgets('one of your own, chosen and changed, is changed rather than copied', (
      tester,
    ) async {
      final kept = <MyFit>[];
      await ask(
        tester,
        () async {
          await tester.tap(find.byType(DropdownButtonFormField<Preset?>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('College form').last);
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(box('Width (pixels)')).controller!.text, '200');
          await tester.enterText(box('At most (KB)'), '40');
          await tester.tap(keep());
          await tester.pump();
          // Its own name, filled in.
          expect(tester.widget<TextField>(box('Slice name')).controller!.text, 'College form');
        },
        mine: const [_college, _bank],
        kept: kept,
      );
      expect(kept.single.id, _college.id);
      expect(kept.single.form.maxBytes, 40000);
    });

    testWidgets('full, the switch says why and stays off', (tester) async {
      final kept = <MyFit>[];
      final form = await ask(
        tester,
        () async {
          expect(tester.widget<SwitchListTile>(keep()).onChanged, isNull);
          expect(find.textContaining('You have 12 slices'), findsOneWidget);
        },
        mine: _many(MyFit.most),
        kept: kept,
      );
      expect(form, isNotNull);
      expect(kept, isEmpty);
    });
  });

  group('in Settings', () {
    Future<SettingsStore> show(WidgetTester tester, List<MyFit> fits) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = SettingsStore(
        AppSettings(myFits: fits, uses: {for (final fit in fits) fit.id: 3}),
        write: (_) async {},
      );
      await tester.pumpWidget(
        _app(
          SettingsScreen(
            desktop: false,
            chooseFolder: () async => null,
            loadPresets: () async => const [],
          ),
          store,
        ),
      );
      return store;
    }

    test('each says what it makes', () {
      final words = lookupWords(const Locale('en'));
      expect(mySliceSummary(words, _college.form), '200 x 230 px, 20-50 KB');
      expect(mySliceSummary(words, _bank.form), '140 x 60 px, up to 20 KB, signature');
      expect(mySliceSummary(words, const FormTarget(minBytes: 10240)), 'at least 10 KB');
      expect(mySliceSummary(words, const FormTarget()), 'Any size');
    });

    testWidgets('they are listed, and one deleted comes back with Undo', (tester) async {
      final store = await show(tester, const [_college, _bank]);
      expect(find.text('College form'), findsOneWidget);
      expect(find.text('140 x 60 px, up to 20 KB, signature'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pump();
      expect(store.value.myFits, [_bank]);
      expect(store.value.uses.containsKey(_college.id), isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('College form deleted.'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(store.value.myFits, [_college, _bank]);
      expect(store.value.uses[_college.id], 3);
    });

    testWidgets('a new one can be made here, without a file', (tester) async {
      final store = await show(tester, const []);
      await tester.tap(find.text('Add a slice'));
      await tester.pumpAndSettle();
      expect(find.text('New slice'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Slice name'), 'Exam photo');
      await tester.enterText(find.widgetWithText(TextField, 'At most (KB)'), '100');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.value.myFits.single.name, 'Exam photo');
      expect(store.value.myFits.single.form.maxBytes, 100000);
      expect(find.text('up to 100 KB'), findsOneWidget);
    });

    testWidgets('one tapped is changed in its place, keeping its id', (tester) async {
      final store = await show(tester, const [_college, _bank]);
      await tester.tap(find.text('College form'));
      await tester.pumpAndSettle();
      expect(find.text('Change slice'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Slice name'), 'University form');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.value.myFits.map((fit) => fit.name), ['University form', 'Bank signature']);
      expect(store.value.myFits.first.id, _college.id);
      expect(store.value.myFits.first.form.width, 200);
    });

    testWidgets('full, there is no Add', (tester) async {
      await show(tester, _many(MyFit.most));
      expect(find.text('Add a slice'), findsNothing);
      expect(find.textContaining('You have 12 slices'), findsOneWidget);
    });
  });
}
