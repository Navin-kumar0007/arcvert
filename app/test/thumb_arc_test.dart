import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radial_core/radial_core.dart';
import 'package:shiftdrop/size_preview.dart';
import 'package:shiftdrop/theme.dart';
import 'package:shiftdrop/thumb_arc.dart';
import 'package:shiftdrop/words.dart';

void main() {
  final tools = actionsFor(const [FileKind.jpg], ActionMode.tools);
  final convert = actionsFor(const [FileKind.png], ActionMode.convert);

  Future<void> pump(
    WidgetTester tester,
    List<RadialAction> actions, {
    required List<String> ran,
    SizeGuesser? sizeOf,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: shiftDropTheme(brightness),
        localizationsDelegates: Words.localizationsDelegates,
        supportedLocales: Words.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ThumbArc(
              actions: actions,
              sizeOf: sizeOf,
              onSelected: (action) => ran.add(action.id),
              onChoice: (action, options) => ran.add('${action.id} ${options.degrees}'),
              onCancelled: () => ran.add('cancel'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the first slice is chosen, and the big button runs it', (tester) async {
    final ran = <String>[];
    await pump(tester, tools, ran: ran);
    final first = actionLabel(wordsFor(const Locale('en')), tools.first.label);
    expect(find.text(first), findsWidgets);
    await tester.tap(find.byType(InkWell).last);
    expect(ran, [tools.first.id]);
  });

  testWidgets('tapping a slice chooses it; Rotate offers its turns as chips', (tester) async {
    final ran = <String>[];
    await pump(tester, tools, ran: ran);
    await tester.tap(find.bySemanticsLabel('Rotate'));
    await tester.pump();
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.text('180°'));
    await tester.pump();
    await tester.tap(find.byType(InkWell).last);
    expect(ran, ['image-rotate 180']);
  });

  testWidgets('shows the size of the chosen slice', (tester) async {
    final ran = <String>[];
    await pump(tester, convert, ran: ran, sizeOf: (action) async => const SizeGuess.about(2048));
    await tester.pump();
    expect(find.textContaining('2 KB'), findsOneWidget);
  });

  testWidgets('more slices than fit turn over with More', (tester) async {
    final ran = <String>[];
    await pump(tester, tools, ran: ran);
    expect(tools.length, greaterThan(5));
    expect(find.bySemanticsLabel('More actions'), findsOneWidget);
    final last = actionLabel(wordsFor(const Locale('en')), tools.last.label);
    expect(find.bySemanticsLabel(last), findsNothing);
    for (var i = 0; i < 3 && find.bySemanticsLabel(last).evaluate().isEmpty; i++) {
      await tester.tap(find.bySemanticsLabel('More actions'));
      await tester.pump();
    }
    expect(find.bySemanticsLabel(last), findsOneWidget);
  });

  testWidgets('Cancel closes it, in dark as in light', (tester) async {
    final ran = <String>[];
    await pump(tester, tools, ran: ran, brightness: Brightness.dark);
    await tester.tap(find.text('Cancel'));
    expect(ran, ['cancel']);
  });
}
