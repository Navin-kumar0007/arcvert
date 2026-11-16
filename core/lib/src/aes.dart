import 'dart:typed_data';

/// AES encryption (FIPS-197) with a 128, 192 or 256-bit key, for locking PDFs. Only encryption:
/// nothing here needs to decrypt. Pure Dart, so it runs the same on every platform.
class AesEncryptor {
  AesEncryptor(Uint8List key) : _rounds = key.length ~/ 4 + 6, _keys = _expand(_checked(key));

  final int _rounds;
  final Uint32List _keys;

  static Uint8List _checked(Uint8List key) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'must be 16, 24 or 32 bytes');
    }
    return key;
  }

  /// Encrypts the 16 bytes of [input] at [at] into [output] at [to].
  void encryptBlock(Uint8List input, int at, Uint8List output, int to) {
    final k = _keys;
    var s0 = _word(input, at) ^ k[0];
    var s1 = _word(input, at + 4) ^ k[1];
    var s2 = _word(input, at + 8) ^ k[2];
    var s3 = _word(input, at + 12) ^ k[3];
    var i = 4;
    for (var round = 1; round < _rounds; round++) {
      final t0 =
          _t0[(s0 >> 24) & 0xFF] ^
          _t1[(s1 >> 16) & 0xFF] ^
          _t2[(s2 >> 8) & 0xFF] ^
          _t3[s3 & 0xFF] ^
          k[i];
      final t1 =
          _t0[(s1 >> 24) & 0xFF] ^
          _t1[(s2 >> 16) & 0xFF] ^
          _t2[(s3 >> 8) & 0xFF] ^
          _t3[s0 & 0xFF] ^
          k[i + 1];
      final t2 =
          _t0[(s2 >> 24) & 0xFF] ^
          _t1[(s3 >> 16) & 0xFF] ^
          _t2[(s0 >> 8) & 0xFF] ^
          _t3[s1 & 0xFF] ^
          k[i + 2];
      final t3 =
          _t0[(s3 >> 24) & 0xFF] ^
          _t1[(s0 >> 16) & 0xFF] ^
          _t2[(s1 >> 8) & 0xFF] ^
          _t3[s2 & 0xFF] ^
          k[i + 3];
      s0 = t0;
      s1 = t1;
      s2 = t2;
      s3 = t3;
      i += 4;
    }
    _last(s0, s1, s2, s3, k[i], output, to);
    _last(s1, s2, s3, s0, k[i + 1], output, to + 4);
    _last(s2, s3, s0, s1, k[i + 2], output, to + 8);
    _last(s3, s0, s1, s2, k[i + 3], output, to + 12);
  }

  /// [data] encrypted in CBC mode from [iv]. With [pad], PKCS #7 padding is added, as PDFs want for
  /// strings and streams; without it, [data] must be whole blocks.
  Uint8List cbc(Uint8List iv, Uint8List data, {bool pad = true}) {
    if (!pad && data.length % 16 != 0) {
      throw ArgumentError.value(data.length, 'data', 'must be whole blocks without padding');
    }
    final extra = pad ? 16 - data.length % 16 : 0;
    final out = Uint8List(data.length + extra)..setRange(0, data.length, data);
    for (var i = data.length; i < out.length; i++) {
      out[i] = extra;
    }
    var previous = iv;
    var previousAt = 0;
    for (var at = 0; at < out.length; at += 16) {
      for (var j = 0; j < 16; j++) {
        out[at + j] ^= previous[previousAt + j];
      }
      encryptBlock(out, at, out, at);
      previous = out;
      previousAt = at;
    }
    return out;
  }

  static int _word(Uint8List b, int at) =>
      (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

  static void _last(int a, int b, int c, int d, int key, Uint8List out, int to) {
    out[to] = _sbox[(a >> 24) & 0xFF] ^ ((key >> 24) & 0xFF);
    out[to + 1] = _sbox[(b >> 16) & 0xFF] ^ ((key >> 16) & 0xFF);
    out[to + 2] = _sbox[(c >> 8) & 0xFF] ^ ((key >> 8) & 0xFF);
    out[to + 3] = _sbox[d & 0xFF] ^ (key & 0xFF);
  }

  static int _subWord(int w) =>
      (_sbox[(w >> 24) & 0xFF] << 24) |
      (_sbox[(w >> 16) & 0xFF] << 16) |
      (_sbox[(w >> 8) & 0xFF] << 8) |
      _sbox[w & 0xFF];

  static Uint32List _expand(Uint8List key) {
    final nk = key.length ~/ 4;
    final total = 4 * (nk + 7);
    final w = Uint32List(total);
    for (var i = 0; i < nk; i++) {
      w[i] = _word(key, i * 4);
    }
    var rcon = 1;
    for (var i = nk; i < total; i++) {
      var t = w[i - 1];
      if (i % nk == 0) {
        t = _subWord(((t << 8) & 0xFFFFFFFF) | ((t >> 24) & 0xFF)) ^ (rcon << 24);
        rcon = _times2(rcon);
      } else if (nk > 6 && i % nk == 4) {
        t = _subWord(t);
      }
      w[i] = w[i - nk] ^ t;
    }
    return w;
  }
}

int _times2(int x) => ((x << 1) ^ ((x & 0x80) != 0 ? 0x1B : 0)) & 0xFF;

final Uint8List _sbox = _makeSbox();

/// The S-box, worked out rather than typed in: stepping through GF(2^8) by multiplying by 3 and
/// dividing by 3 at once gives each element with its inverse, then the affine step.
Uint8List _makeSbox() {
  final box = Uint8List(256);
  int rotl(int x, int by) => ((x << by) | (x >> (8 - by))) & 0xFF;
  var p = 1;
  var q = 1;
  do {
    p = p ^ _times2(p);
    q ^= q << 1;
    q ^= q << 2;
    q ^= q << 4;
    q &= 0xFF;
    if (q & 0x80 != 0) q ^= 0x09;
    box[p] = q ^ rotl(q, 1) ^ rotl(q, 2) ^ rotl(q, 3) ^ rotl(q, 4) ^ 0x63;
  } while (p != 1);
  box[0] = 0x63;
  return box;
}

Uint32List _table(int by) {
  final table = Uint32List(256);
  for (var x = 0; x < 256; x++) {
    final s = _sbox[x];
    final s2 = _times2(s);
    final word = (s2 << 24) | (s << 16) | (s << 8) | (s2 ^ s);
    table[x] = by == 0 ? word : ((word >> by) | (word << (32 - by))) & 0xFFFFFFFF;
  }
  return table;
}

final Uint32List _t0 = _table(0);
final Uint32List _t1 = _table(8);
final Uint32List _t2 = _table(16);
final Uint32List _t3 = _table(24);
