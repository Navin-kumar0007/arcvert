import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

void main() {
  final facts = reportFacts(appVersion: '0.15.0', platform: 'macOS', language: 'hi');

  test('the facts are the app, the platform and the language only', () {
    expect(facts, 'ShiftDrop 0.15.0\nPlatform: macOS\nLanguage: hi');
  });

  test('a problem report opens a new GitHub issue holding what was typed and the facts', () {
    final address = problemReport(facts: facts, what: '  The PDF came out blank.  ');
    expect(address.scheme, 'https');
    expect(address.host, 'github.com');
    expect(address.path, '/Navin-kumar0007/shiftdrop/issues/new');
    expect(address.queryParameters['labels'], 'bug');
    final body = address.queryParameters['body']!;
    expect(body, contains('The PDF came out blank.\n'));
    expect(body, contains('ShiftDrop 0.15.0\nPlatform: macOS'));
  });

  test('with nothing typed, it asks for a description there', () {
    final body = problemReport(facts: facts).queryParameters['body']!;
    expect(body, contains('Please describe what happened'));
  });

  test('a long description is cut short, so the address still opens', () {
    final address = problemReport(facts: facts, what: 'x' * 5000);
    expect(address.queryParameters['body']!.split('x').length - 1, maxReportText);
    expect(address.toString().length, lessThan(8000));
  });

  test('an idea opens a new issue labelled as one', () {
    final address = featureIdea(appVersion: '0.15.0');
    expect(address.queryParameters['labels'], 'idea');
    expect(address.queryParameters['body'], contains('ShiftDrop 0.15.0'));
  });

  group('by email', () {
    test('a report is a draft to the address, with spaces that stay spaces', () {
      final address = problemEmail(to: 'help@example.org', facts: facts, what: 'It froze & quit.');
      expect(address.scheme, 'mailto');
      expect(address.path, 'help@example.org');
      expect(address.toString(), isNot(contains('+')));
      expect(address.queryParameters['subject'], 'ShiftDrop problem');
      final body = address.queryParameters['body']!;
      expect(body, startsWith('It froze & quit.\n'));
      expect(body, contains('ShiftDrop 0.15.0\nPlatform: macOS'));
    });

    test('an idea is a draft too', () {
      final address = ideaEmail(to: 'help@example.org', appVersion: '0.15.0');
      expect(address.queryParameters['subject'], 'ShiftDrop idea');
      expect(address.queryParameters['body'], contains('ShiftDrop 0.15.0'));
    });

    test('the address is set once there is one, and looks like an address', () {
      final email = supportEmail;
      if (email != null) expect(email, matches(RegExp(r'^[^@\s]+@[^@\s]+\.[a-z]+$')));
    });
  });
}
