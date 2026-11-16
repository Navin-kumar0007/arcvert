import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftdrop/about.dart';
import 'package:shiftdrop/help_screen.dart';
import 'package:shiftdrop/words.dart';

void main() {
  late List<Uri> opened;
  var opens = true;

  Future<void> pump(WidgetTester tester, HelpPlace place, {Locale? locale, String? email}) async {
    opened = [];
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: Words.localizationsDelegates,
        supportedLocales: Words.supportedLocales,
        home: HelpScreen(
          place: place,
          email: email,
          open: (address) async {
            opened.add(address);
            return opens;
          },
        ),
      ),
    );
  }

  test('What\'s new describes this version', () => expect(whatsNewVersion, appVersion));

  testWidgets('a Mac gets its own questions and keys, not Windows\'', (tester) async {
    await pump(tester, HelpPlace.mac);
    expect(find.text('The menu doesn\'t appear when I drag a file.'), findsOne);
    expect(find.text('macOS says the app can\'t be checked.'), findsOne);
    expect(find.text('Windows warns about the app when I open it.'), findsNothing);
    expect(find.text('Option'), findsOne);
    expect(find.text('Alt'), findsNothing);
  });

  testWidgets('Windows gets the Alt and SmartScreen questions', (tester) async {
    await pump(tester, HelpPlace.windows);
    expect(find.text('Alt with Shift changes my keyboard language.'), findsOne);
    expect(find.text('Windows warns about the app when I open it.'), findsOne);
    expect(find.text('Alt'), findsOne);
  });

  testWidgets('a phone has no Shift-drag questions and no keyboard shortcuts', (tester) async {
    await pump(tester, HelpPlace.phone);
    expect(find.text('The menu doesn\'t appear when I drag a file.'), findsNothing);
    expect(find.text('Keyboard shortcuts'.toUpperCase()), findsNothing);
    expect(find.text('Are my files uploaded anywhere?'), findsOne);
  });

  testWidgets('an answer opens from its question', (tester) async {
    await pump(tester, HelpPlace.browser);
    await tester.tap(find.text('Are my files uploaded anywhere?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Everything happens on this device'), findsOne);
  });

  testWidgets('searching finds answers by their words, and says when nothing matches', (
    tester,
  ) async {
    await pump(tester, HelpPlace.mac);
    await tester.enterText(find.byType(TextField), 'kb');
    await tester.pumpAndSettle();
    expect(find.text('A form says my photo or signature is the wrong size.'), findsOne);
    expect(find.textContaining('1000 bytes'), findsOne, reason: 'Found answers open at once');
    expect(find.text('How do I convert a file?'), findsNothing);
    expect(find.text('Report a problem'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pumpAndSettle();
    expect(find.text('Nothing in help matches "zebra".'), findsOne);
  });

  testWidgets('a report shows what it holds, then opens GitHub with it', (tester) async {
    await pump(tester, HelpPlace.mac);
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ShiftDrop $appVersion'), findsOne);
    await tester.enterText(find.byType(TextField).last, 'The PDF came out blank.');
    await tester.tap(find.text('Report on GitHub'));
    await tester.pumpAndSettle();
    final address = opened.single;
    expect(address.host, 'github.com');
    expect(address.queryParameters['body'], contains('The PDF came out blank.'));
    expect(address.queryParameters['body'], contains('ShiftDrop $appVersion'));
  });

  testWidgets('cancelling a report opens nothing', (tester) async {
    await pump(tester, HelpPlace.mac);
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('a report can be copied instead', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, HelpPlace.mac);
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'It froze.');
    await tester.tap(find.text('Copy instead'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(copied, startsWith('It froze.\n\nShiftDrop $appVersion'));
    expect(find.text('Copied. Paste it into an email or a report.'), findsOne);
  });

  testWidgets('suggesting an idea opens GitHub, and a page that won\'t open says so', (
    tester,
  ) async {
    await pump(tester, HelpPlace.windows);
    opens = false;
    addTearDown(() => opens = true);
    await tester.tap(find.text('Suggest a feature'));
    await tester.pumpAndSettle();
    expect(opened.single.queryParameters['labels'], 'idea');
    expect(find.byType(SnackBar), findsOne);
  });

  testWidgets('in Hindi', (tester) async {
    await pump(tester, HelpPlace.mac, locale: const Locale('hi'));
    expect(find.text('मदद'), findsOne);
    expect(find.text('समस्या बताएँ'), findsOne);
  });

  group('with a support address', () {
    const address = 'help@example.org';

    testWidgets('a report goes by email first, as a draft to send', (tester) async {
      await pump(tester, HelpPlace.phone, email: address);
      await tester.tap(find.text('Report a problem'));
      await tester.pumpAndSettle();
      expect(find.text('Report on GitHub'), findsOne, reason: 'GitHub stays as a second way');
      await tester.enterText(find.byType(TextField).last, 'Nothing happened.');
      await tester.tap(find.text('Send by email'));
      await tester.pumpAndSettle();
      final draft = opened.single;
      expect(draft.scheme, 'mailto');
      expect(draft.path, address);
      expect(draft.queryParameters['body'], startsWith('Nothing happened.'));
    });

    testWidgets('an idea goes by email, or GitHub from its own button', (tester) async {
      await pump(tester, HelpPlace.mac, email: address);
      expect(find.text('Or write to $address'), findsOne);
      await tester.tap(find.text('Suggest a feature'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Suggest on GitHub'));
      await tester.pumpAndSettle();
      expect(opened.map((uri) => uri.scheme), ['mailto', 'https']);
    });
  });

  testWidgets('without one, there is no email button or address', (tester) async {
    await pump(tester, HelpPlace.mac);
    expect(find.textContaining('write to'), findsNothing);
    await tester.tap(find.text('Report a problem'));
    await tester.pumpAndSettle();
    expect(find.text('Send by email'), findsNothing);
  });
}
