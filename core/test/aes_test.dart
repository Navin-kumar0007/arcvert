import 'dart:typed_data';

import 'package:radial_core/src/aes.dart';
import 'package:test/test.dart';

Uint8List _hex(String text) => Uint8List.fromList([
  for (var i = 0; i < text.length; i += 2) int.parse(text.substring(i, i + 2), radix: 16),
]);

String _text(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final plain = _hex('00112233445566778899aabbccddeeff');

  // FIPS-197, appendix C.
  for (final (key, expected) in [
    ('000102030405060708090a0b0c0d0e0f', '69c4e0d86a7b0430d8cdb78070b4c55a'),
    ('000102030405060708090a0b0c0d0e0f1011121314151617', 'dda97ca4864cdfe06eaf70a0ec0d7191'),
    (
      '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
      '8ea2b7ca516745bfeafc49904b496089',
    ),
  ]) {
    test('a ${key.length * 4}-bit key gives the standard\'s block', () {
      final out = Uint8List(16);
      AesEncryptor(_hex(key)).encryptBlock(plain, 0, out, 0);
      expect(_text(out), expected);
    });
  }

  test('CBC matches NIST SP 800-38A, F.2.5', () {
    final aes = AesEncryptor(
      _hex('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4'),
    );
    final out = aes.cbc(
      _hex('000102030405060708090a0b0c0d0e0f'),
      _hex('6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51'),
      pad: false,
    );
    expect(_text(out), 'f58c4c04d6e5f1ba779eabfb5f7bfbd69cfc4e967edb808d679f777bc6702c7d');
  });

  test('padding always adds up to a whole block, a full one when it was already whole', () {
    final aes = AesEncryptor(Uint8List(32));
    expect(aes.cbc(Uint8List(16), Uint8List(0)).length, 16);
    expect(aes.cbc(Uint8List(16), Uint8List(15)).length, 16);
    expect(aes.cbc(Uint8List(16), Uint8List(16)).length, 32);
    expect(() => aes.cbc(Uint8List(16), Uint8List(5), pad: false), throwsArgumentError);
    expect(() => AesEncryptor(Uint8List(10)), throwsArgumentError);
  });
}
