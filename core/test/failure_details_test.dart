import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

void main() {
  test('says the version, platform, action, kind and key, one to a line', () {
    final text = failureDetails(
      appVersion: '0.12.0',
      platform: 'macOS',
      action: 'Compress',
      kind: FileKind.jpg,
      failure: Fail.damaged('holiday.jpg'),
    );
    expect(
      text,
      'ShiftDrop 0.12.0\n'
      'Platform: macOS\n'
      'Action: Compress\n'
      'File kind: image (jpg)\n'
      'Error: damaged',
    );
  });

  test('never holds a file name, folder or what an engine printed', () {
    final failure = Fail.tooManyToSave(
      '/Users/someone/Private/taxes 2026.zip',
      900,
      50,
    ).withDetails('ffmpeg: /Users/someone/Private/taxes 2026.zip: Invalid data');
    final text = failureDetails(
      appVersion: '0.12.0',
      platform: 'Windows',
      action: 'Extract',
      kind: FileKind.zip,
      failure: failure,
    );
    expect(text, isNot(contains('taxes')));
    expect(text, isNot(contains('someone')));
    expect(text, isNot(contains('Invalid data')));
    expect(text, contains('Error: tooManyToSave'));
  });

  test('says when the kind or the failure is not known', () {
    final text = failureDetails(appVersion: '0.12.0', platform: 'Web', action: 'To PNG');
    expect(text, contains('File kind: unknown'));
    expect(text, contains('Error: unexpected'));
    expect(
      failureDetails(
        appVersion: '0.12.0',
        platform: 'Web',
        action: 'To PNG',
        failure: const EngineFailed('Too large.'),
      ),
      contains('Error: unnamed'),
    );
  });
}
