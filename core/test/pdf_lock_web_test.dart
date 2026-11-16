// Runs in a browser too (`dart test -p chrome test/pdf_lock_web_test.dart`), where integers are
// JavaScript numbers: AES and the password hash must give the same bytes there as here.
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

/// The same "random" bytes everywhere, so results can be compared.
class _Steady implements Random {
  var _n = 0;

  @override
  int nextInt(int max) => (_n++ * 7 + 3) % max;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => true;
}

void main() {
  test('locking gives the same bytes on every platform', () {
    final photo = img.Image(width: 16, height: 12);
    final pdf = buildImagePdf([img.encodeJpg(photo, quality: 90)]);
    final locked = lockPdf(pdf, 'पासवर्ड and more', random: _Steady());
    expect(
      sha256.convert(locked).toString(),
      'e96c3d7eec413db369bc3f95b220cd5386e2029b591b3976e1bc4ee48818346b',
    );
  });
}
