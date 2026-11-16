import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseClock', () {
    final good = {
      '0': 0.0,
      '90': 90.0,
      '1.5': 1.5,
      '1:30': 90.0,
      ' 1:30 ': 90.0,
      '1:30.5': 90.5,
      '90:00': 5400.0,
      '1:02:03': 3723.0,
      '0:00': 0.0,
    };
    good.forEach((text, seconds) {
      test(text, () => expect(parseClock(text), seconds));
    });

    for (final text in ['', 'abc', '1:', ':30', '1:90', '1:2:3:4', '-5', '1.5:00', '1:2:60']) {
      test('"$text" is not a time', () => expect(parseClock(text), isNull));
    }
  });

  group('writing a time', () {
    test('as people write it', () {
      expect(formatClock(0), '0:00');
      expect(formatClock(5), '0:05');
      expect(formatClock(65), '1:05');
      expect(formatClock(600), '10:00');
      expect(formatClock(3723), '1:02:03');
    });

    test('tenths only when there are some', () {
      expect(formatClock(1.5), '0:01.5');
      expect(formatClock(90.25), '1:30.3');
      expect(formatClock(59.96), '1:00');
    });

    test('nothing below zero', () => expect(formatClock(-3), '0:00'));

    test('reads back as what it says', () {
      for (final seconds in const [0.0, 1.5, 59.9, 60.0, 90.5, 3599.9, 3600.0, 7384.2]) {
        expect(parseClock(formatClock(seconds)), closeTo(seconds, 0.001), reason: '$seconds');
      }
    });
  });

  test('a password joins what was already chosen', () {
    const options = ActionOptions(degrees: 90, newPassword: 'n', startSeconds: 2);
    final withPassword = options.withPassword('p');
    expect(withPassword.password, 'p');
    expect(withPassword.degrees, 90);
    expect(withPassword.newPassword, 'n');
    expect(withPassword.startSeconds, 2);
  });

  group('to and from a browser worker', () {
    const everything = ActionOptions(
      longSide: 1280,
      crop: (left: 1, top: 2, width: 3, height: 4),
      degrees: 270,
      flipVertical: true,
      startSeconds: 1.5,
      endSeconds: 9.25,
      pages: '1-3,7',
      password: 'open sesame',
      newPassword: 'new one',
      audioKbps: 128,
      targetMb: 0.5,
      shift: Duration(milliseconds: -1500),
      form: FormTarget(width: 140, height: 60, minBytes: 10240, maxBytes: 20000),
    );

    test('every choice comes back as it went', () {
      final back = ActionOptions.fromWire(everything.toWire());
      expect(back.toWire(), everything.toWire());
      expect(back.degrees, 270);
      expect(back.flipVertical, isTrue);
      expect(back.longSide, 1280);
    });

    test('a new choice has to be added here too', () {
      // ActionOptions has 13 choices. One added without toWire and fromWire reaches every engine
      // but a browser's, as Rotate's and Resize's ring choices once did.
      expect(everything.toWire().keys, hasLength(13));
      expect(everything.toWire().values.where((value) => value == null), isEmpty);
    });

    test('numbers survive a browser, where whole numbers and decimals are one kind', () {
      final wire = everything.toWire()
        ..['degrees'] = 270.0
        ..['crop'] = [1.0, 2.0, 3.0, 4.0];
      final back = ActionOptions.fromWire(wire);
      expect(back.degrees, 270);
      expect(back.crop, (left: 1, top: 2, width: 3, height: 4));
    });
  });
}
