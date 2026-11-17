import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arcvert/page_picker.dart';
import 'package:arcvert/words.dart';

void main() {
  Future<String?> Function() open(WidgetTester tester) {
    String? chosen;
    var done = false;
    return () async {
      if (!done) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: Words.localizationsDelegates,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await askForPages(context);
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }
      return chosen;
    };
  }

  testWidgets('without the PDF at hand, pages can still be typed', (tester) async {
    await open(tester)();
    expect(find.textContaining("can't be shown"), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1-3, 7');
    await tester.tap(find.text('Extract'));
    await tester.pumpAndSettle();
    expect(find.byType(PagePickerDialog), findsNothing);
  });

  testWidgets('nothing typed says to choose a page, and stays open', (tester) async {
    await open(tester)();
    await tester.tap(find.text('Extract'));
    await tester.pump();
    expect(find.text('Choose at least one page.'), findsOneWidget);
    expect(find.byType(PagePickerDialog), findsOneWidget);
  });

  testWidgets('Cancel gives nothing', (tester) async {
    await open(tester)();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PagePickerDialog), findsNothing);
  });
}
