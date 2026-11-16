import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:crypto/crypto.dart';

import 'aes.dart';

/// [pdf] rewritten so that it opens only with [password], encrypted with AES-256 (revision 6, as
/// PDF 2.0 and Acrobat X onwards have it). Any PDF reader that opens it with the password can do
/// everything with it, as qpdf's `--encrypt` with one password did.
///
/// Pure Dart, so every platform locks PDFs the same way. Every object is read and written again:
/// cross-reference tables or streams, object streams and later updates are all followed, and the
/// result has one plain table. Throws a [FormatException] if [pdf] can't be followed, or is
/// encrypted already: give PDFium's copy of it instead, which is always plain.
///
/// Passwords are taken as UTF-8, up to 127 bytes as the standard says, without SASLprep: readers
/// that skip it (pdf.js, qpdf) and those that apply it agree for any password typed normally.
Uint8List lockPdf(Uint8List pdf, String password, {Random? random}) {
  final rng = random ?? Random.secure();
  final file = _PdfFile(pdf);
  final trailer = file.trailer;
  if (trailer.entries.containsKey('Encrypt')) {
    throw const FormatException('This PDF is encrypted already.');
  }
  final root = trailer.entries['Root'];
  if (root is! _Ref) throw const FormatException('This PDF has no catalog.');

  final key = _random(rng, 32);
  final lock = _Lock(key, rng);
  final out = _Writer();
  final version = file.version < 1.7 ? 1.7 : file.version;
  out.text('%PDF-${version.toStringAsFixed(1)}\n%');
  out.bytes(Uint8List.fromList([0xE2, 0xE3, 0xCF, 0xD3, 0x0A]));

  final offsets = <int, (int, int)>{};
  var highest = 0;
  for (final number in file.numbers) {
    final value = file.load(number);
    if (value == null || _dropped(value)) continue;
    var written = value;
    if (number == root.number && version < 2 && value is _Dict) {
      written = _withExtension(value);
    }
    final generation = file.generation(number);
    offsets[number] = (out.length, generation);
    if (number > highest) highest = number;
    out.text('$number $generation obj\n');
    if (written is _Stream) {
      final data = lock.encrypt(written.data);
      final dict = _Dict({...written.dict.entries, 'Length': _Raw('${data.length}')});
      _write(out, dict, lock);
      out.text('\nstream\n');
      out.bytes(data);
      out.text('\nendstream');
    } else {
      _write(out, written, lock);
    }
    out.text('\nendobj\n');
  }

  final size = max(highest + 1, _int(trailer.entries['Size']) ?? 0);
  final encryptNumber = size;
  final userSalt = _random(rng, 16);
  final ownerSalt = _random(rng, 16);
  final secret = _passwordBytes(password);
  final u = Uint8List.fromList([
    ..._hash(secret, userSalt.sublist(0, 8), Uint8List(0)),
    ...userSalt,
  ]);
  final ue = AesEncryptor(
    _hash(secret, userSalt.sublist(8), Uint8List(0)),
  ).cbc(Uint8List(16), key, pad: false);
  final o = Uint8List.fromList([..._hash(secret, ownerSalt.sublist(0, 8), u), ...ownerSalt]);
  final oe = AesEncryptor(
    _hash(secret, ownerSalt.sublist(8), u),
  ).cbc(Uint8List(16), key, pad: false);
  const permissions = -4;
  final perms = Uint8List(16)
    ..buffer.asByteData().setInt32(0, permissions, Endian.little)
    ..setRange(4, 12, [0xFF, 0xFF, 0xFF, 0xFF, 0x54, 0x61, 0x64, 0x62])
    ..setRange(12, 16, _random(rng, 4));
  AesEncryptor(key).encryptBlock(perms, 0, perms, 0);

  offsets[encryptNumber] = (out.length, 0);
  out.text(
    '$encryptNumber 0 obj\n<< /Filter /Standard /V 5 /R 6 /Length 256 /P $permissions '
    '/EncryptMetadata true /CF << /StdCF << /AuthEvent /DocOpen /CFM /AESV3 /Length 32 >> >> '
    '/StmF /StdCF /StrF /StdCF /O <${_hexOf(o)}> /U <${_hexOf(u)}> /OE <${_hexOf(oe)}> '
    '/UE <${_hexOf(ue)}> /Perms <${_hexOf(perms)}> >>\nendobj\n',
  );

  final tableAt = out.length;
  out.text('xref\n0 ${size + 1}\n0000000000 65535 f\r\n');
  for (var number = 1; number <= size; number++) {
    final place = offsets[number];
    out.text(
      place == null
          ? '0000000000 00000 f\r\n'
          : '${'${place.$1}'.padLeft(10, '0')} ${'${place.$2}'.padLeft(5, '0')} n\r\n',
    );
  }
  final ids = trailer.entries['ID'];
  final first = ids is List && ids.isNotEmpty && ids.first is _Str
      ? (ids.first as _Str).bytes
      : _random(rng, 16);
  out.text('trailer\n<< /Size ${size + 1} /Root ${root.number} ${root.generation} R');
  final info = trailer.entries['Info'];
  if (info is _Ref) out.text(' /Info ${info.number} ${info.generation} R');
  out.text(
    ' /ID [<${_hexOf(first)}> <${_hexOf(_random(rng, 16))}>] /Encrypt $encryptNumber 0 R >>\n'
    'startxref\n$tableAt\n%%EOF\n',
  );
  return out.result();
}

/// Objects that only described the old file's layout: its cross-reference and object streams,
/// whose contents are written out on their own, and linearization, whose offsets no longer hold.
bool _dropped(Object value) {
  if (value is _Stream) {
    final type = value.dict.entries['Type'];
    return type is _Name && (type.raw == 'XRef' || type.raw == 'ObjStm');
  }
  return value is _Dict && value.entries.containsKey('Linearized');
}

/// The catalog saying it uses Adobe's extension level 8, which is how a PDF 1.7 announces AES-256.
_Dict _withExtension(_Dict catalog) {
  const adbe = _Dict({'BaseVersion': _Name('1.7'), 'ExtensionLevel': _Raw('8')});
  final present = catalog.entries['Extensions'];
  if (present is _Ref) return catalog;
  final extensions = present is _Dict ? {...present.entries, 'ADBE': adbe} : {'ADBE': adbe};
  return _Dict({...catalog.entries, 'Extensions': _Dict(extensions)});
}

Uint8List _random(Random rng, int count) =>
    Uint8List.fromList([for (var i = 0; i < count; i++) rng.nextInt(256)]);

Uint8List _passwordBytes(String password) {
  final bytes = utf8.encode(password);
  return Uint8List.fromList(bytes.length > 127 ? bytes.sublist(0, 127) : bytes);
}

/// The hash of ISO 32000-2, algorithm 2.B, for revision 6.
Uint8List _hash(Uint8List password, Uint8List salt, Uint8List userKey) {
  var k = Uint8List.fromList(sha256.convert([...password, ...salt, ...userKey]).bytes);
  var e = Uint8List(0);
  var round = 0;
  while (round < 64 || e.last > round - 32) {
    final part = [...password, ...k, ...userKey];
    final k1 = Uint8List(part.length * 64);
    for (var i = 0; i < 64; i++) {
      k1.setRange(i * part.length, (i + 1) * part.length, part);
    }
    e = AesEncryptor(k.sublist(0, 16)).cbc(k.sublist(16, 32), k1, pad: false);
    var sum = 0;
    for (var i = 0; i < 16; i++) {
      sum += e[i];
    }
    final next = switch (sum % 3) {
      0 => sha256.convert(e),
      1 => sha384.convert(e),
      _ => sha512.convert(e),
    };
    k = Uint8List.fromList(next.bytes);
    round++;
  }
  return k.sublist(0, 32);
}

/// Strings and streams encrypted with the file key, each with its own random start.
class _Lock {
  _Lock(Uint8List key, this._rng) : _aes = AesEncryptor(key);

  final AesEncryptor _aes;
  final Random _rng;

  Uint8List encrypt(Uint8List data) {
    final iv = _random(_rng, 16);
    final sealed = _aes.cbc(iv, data);
    return Uint8List(16 + sealed.length)
      ..setRange(0, 16, iv)
      ..setRange(16, 16 + sealed.length, sealed);
  }
}

// What a PDF is made of, as read.

class _Name {
  const _Name(this.raw);

  /// As written, after the slash, escapes and all.
  final String raw;
}

class _Raw {
  const _Raw(this.text);

  /// A number, true, false or null, as written.
  final String text;
}

class _Ref {
  const _Ref(this.number, this.generation);

  final int number;
  final int generation;
}

class _Str {
  const _Str(this.bytes);

  final Uint8List bytes;
}

class _Dict {
  const _Dict(this.entries);

  final Map<String, Object> entries;
}

class _Stream {
  _Stream(this.dict, this.data);

  final _Dict dict;

  /// As stored, still compressed.
  final Uint8List data;
}

int? _int(Object? value) => value is _Raw ? int.tryParse(value.text) : null;

/// Where an object is: at an offset in the file, or the [index]th in object stream [stream].
class _Entry {
  const _Entry.at(this.offset, this.generation) : stream = null, index = 0;
  const _Entry.inside(int this.stream, this.index) : offset = 0, generation = 0;
  const _Entry.free() : offset = -1, generation = 0, stream = null, index = 0;

  final int offset;
  final int generation;
  final int? stream;
  final int index;

  bool get isFree => offset < 0;
}

class _PdfFile {
  _PdfFile(this.bytes) {
    version = _readVersion();
    final start = _startXref();
    // Some files have bytes before the header, such as a byte-order mark, which their offsets
    // don't count. Readers allow for that, so this does too.
    final header = _find(bytes, '%PDF-', 0);
    if (header > 0 && !_sectionAt(start) && _sectionAt(start + header)) _shift = header;
    final sections = <int>{};
    int? next = start;
    _Dict? newest;
    while (next != null) {
      if (!sections.add(next)) break;
      final (found, dict) = _section(next);
      newest ??= dict;
      for (final MapEntry(:key, :value) in found.entries) {
        _entries.putIfAbsent(key, () => value);
      }
      for (final name in ['Root', 'Info', 'ID', 'Encrypt']) {
        if (!_trailer.containsKey(name) && dict.entries.containsKey(name)) {
          _trailer[name] = dict.entries[name]!;
        }
      }
      next = _int(dict.entries['Prev']);
    }
    _trailer['Size'] = newest?.entries['Size'] ?? const _Raw('0');
  }

  final Uint8List bytes;
  late final double version;
  var _shift = 0;
  final _entries = <int, _Entry>{};
  final _trailer = <String, Object>{};
  final _loaded = <int, Object?>{};
  final _objectStreams = <int, List<Object>>{};

  _Dict get trailer => _Dict(_trailer);

  /// Every object in use, lowest first.
  List<int> get numbers => [
    for (final MapEntry(:key, :value) in _entries.entries)
      if (!value.isFree && key > 0) key,
  ]..sort();

  int generation(int number) => _entries[number]?.generation ?? 0;

  double _readVersion() {
    final head = latin1.decode(bytes.sublist(0, min(1024, bytes.length)));
    final match = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(head);
    if (match == null) throw const FormatException('Not a PDF.');
    return double.parse(match.group(1)!);
  }

  int _startXref() {
    final from = max(0, bytes.length - 2048);
    final tail = latin1.decode(bytes.sublist(from));
    final at = tail.lastIndexOf('startxref');
    if (at < 0) throw const FormatException('No startxref.');
    final match = RegExp(r'startxref\s+(\d+)').matchAsPrefix(tail, at);
    if (match == null) throw const FormatException('Bad startxref.');
    return int.parse(match.group(1)!);
  }

  bool _sectionAt(int offset) {
    if (offset < 0 || offset >= bytes.length) return false;
    final reader = _Reader(bytes, offset)..skipSpace();
    if (reader.startsWith('xref')) return true;
    final number = reader.word();
    final generation = reader.word();
    return number != null &&
        generation != null &&
        int.tryParse(number) != null &&
        int.tryParse(generation) != null &&
        reader.word() == 'obj';
  }

  /// One cross-reference section: a table, with any stream a hybrid file adds, or a stream.
  (Map<int, _Entry>, _Dict) _section(int offset) {
    final reader = _Reader(bytes, offset + _shift)..skipSpace();
    if (reader.startsWith('xref')) {
      reader.pos += 4;
      final found = <int, _Entry>{};
      while (true) {
        final word = reader.word();
        if (word == 'trailer') break;
        final start = int.parse(word ?? '');
        final count = int.parse(reader.word() ?? '');
        for (var i = 0; i < count; i++) {
          final at = int.parse(reader.word() ?? '');
          final gen = int.parse(reader.word() ?? '');
          final kind = reader.word();
          // An object in use at offset 0 can't be anywhere: readers take it as free.
          found[start + i] = kind == 'n' && at > 0 ? _Entry.at(at, gen) : const _Entry.free();
        }
      }
      final dict = reader.value();
      if (dict is! _Dict) throw const FormatException('Bad trailer.');
      final hidden = _int(dict.entries['XRefStm']);
      if (hidden != null) {
        // A hybrid file's stream lists what the table, for older readers, leaves free.
        final (more, _) = _streamSection(hidden);
        for (final MapEntry(:key, :value) in more.entries) {
          if (found[key]?.isFree ?? true) found[key] = value;
        }
      }
      return (found, dict);
    }
    return _streamSection(offset);
  }

  (Map<int, _Entry>, _Dict) _streamSection(int offset) {
    final (_, _, value) = _indirectAt(offset);
    if (value is! _Stream) throw const FormatException('Bad cross-reference stream.');
    final dict = value.dict.entries;
    final widths = [for (final w in dict['W'] as List) _int(w)!];
    if (widths.length != 3) throw const FormatException('Bad /W.');
    final index = dict['Index'] is List
        ? [for (final i in dict['Index'] as List) _int(i)!]
        : [0, _int(dict['Size'])!];
    final data = _decode(value);
    final row = widths[0] + widths[1] + widths[2];
    final found = <int, _Entry>{};
    var at = 0;
    int field(int width, int fallback) {
      if (width == 0) return fallback;
      var n = 0;
      for (var i = 0; i < width; i++) {
        n = n * 256 + data[at++];
      }
      return n;
    }

    for (var i = 0; i + 1 < index.length; i += 2) {
      for (var j = 0; j < index[i + 1]; j++) {
        if (at + row > data.length) throw const FormatException('Short cross-reference stream.');
        final type = field(widths[0], 1);
        final a = field(widths[1], 0);
        final b = field(widths[2], 0);
        found[index[i] + j] = switch (type) {
          1 => _Entry.at(a, b),
          2 => _Entry.inside(a, b),
          _ => const _Entry.free(),
        };
      }
    }
    return (found, value.dict);
  }

  /// The object numbered [number], or null if it isn't there.
  Object? load(int number) {
    if (_loaded.containsKey(number)) return _loaded[number];
    final entry = _entries[number];
    Object? value;
    if (entry == null || entry.isFree) {
      value = null;
    } else if (entry.stream case final stream?) {
      final inside = _objectStreams[stream] ??= _readObjectStream(stream);
      if (entry.index >= inside.length) throw const FormatException('Bad object stream index.');
      value = inside[entry.index];
    } else {
      final (n, _, found) = _indirectAt(entry.offset);
      if (n != number) throw FormatException('Object $number is not where the table says.');
      value = found;
    }
    _loaded[number] = value;
    return value;
  }

  List<Object> _readObjectStream(int number) {
    final holder = load(number);
    if (holder is! _Stream) throw const FormatException('Bad object stream.');
    final count = _int(holder.dict.entries['N'])!;
    final first = _int(holder.dict.entries['First'])!;
    final data = _decode(holder);
    final header = _Reader(data, 0);
    final offsets = <int>[];
    for (var i = 0; i < count; i++) {
      header.word();
      offsets.add(int.parse(header.word() ?? ''));
    }
    return [for (final at in offsets) _Reader(data, first + at).value()];
  }

  (int, int, Object) _indirectAt(int offset) {
    final reader = _Reader(bytes, offset + _shift);
    final number = int.parse(reader.word() ?? '');
    final generation = int.parse(reader.word() ?? '');
    if (reader.word() != 'obj') throw const FormatException('Expected obj.');
    final value = reader.value();
    if (value is _Dict) {
      final before = reader.pos;
      if (reader.word() == 'stream') {
        return (number, generation, _Stream(value, _streamData(reader, value)));
      }
      reader.pos = before;
    }
    return (number, generation, value);
  }

  Uint8List _streamData(_Reader reader, _Dict dict) {
    var start = reader.pos;
    if (start < bytes.length && bytes[start] == 0x0D) start++;
    if (start < bytes.length && bytes[start] == 0x0A) start++;
    final lengthEntry = dict.entries['Length'];
    var length = _int(lengthEntry);
    if (lengthEntry is _Ref) length = _int(load(lengthEntry.number));
    if (length != null && start + length <= bytes.length) {
      final after = _Reader(bytes, start + length);
      if (after.word() == 'endstream') return Uint8List.sublistView(bytes, start, start + length);
    }
    // A wrong length is common enough to look for the end instead.
    final end = _find(bytes, 'endstream', start);
    if (end < 0) throw const FormatException('No endstream.');
    var stop = end;
    if (stop > start && bytes[stop - 1] == 0x0A) stop--;
    if (stop > start && bytes[stop - 1] == 0x0D) stop--;
    return Uint8List.sublistView(bytes, start, stop);
  }

  /// A cross-reference or object stream unpacked. Only Flate is used for those in practice.
  Uint8List _decode(_Stream stream) {
    var filter = stream.dict.entries['Filter'];
    var parms = stream.dict.entries['DecodeParms'];
    if (filter is List) {
      if (filter.length > 1) throw const FormatException('Only one filter is read.');
      filter = filter.isEmpty ? null : filter.first;
      if (parms is List) parms = parms.isEmpty ? null : parms.first;
    }
    if (filter == null) return stream.data;
    if (filter is! _Name || (filter.raw != 'FlateDecode' && filter.raw != 'Fl')) {
      throw const FormatException('Unsupported filter.');
    }
    Uint8List data;
    try {
      data = const ZLibDecoder().decodeBytes(stream.data);
    } catch (_) {
      throw const FormatException('Damaged compressed stream.');
    }
    if (parms is _Ref) parms = load(parms.number);
    final predictor = parms is _Dict ? _int(parms.entries['Predictor']) ?? 1 : 1;
    if (predictor == 1) return data;
    if (predictor < 10) throw const FormatException('Unsupported predictor.');
    final p = parms as _Dict;
    final columns = _int(p.entries['Columns']) ?? 1;
    final colors = _int(p.entries['Colors']) ?? 1;
    final bits = _int(p.entries['BitsPerComponent']) ?? 8;
    return _unpredictPng(data, columns, colors, bits);
  }
}

Uint8List _unpredictPng(Uint8List data, int columns, int colors, int bits) {
  final pixel = max(1, colors * bits ~/ 8);
  final rowLength = (columns * colors * bits + 7) ~/ 8;
  final rows = data.length ~/ (rowLength + 1);
  final out = Uint8List(rows * rowLength);
  for (var r = 0; r < rows; r++) {
    final filter = data[r * (rowLength + 1)];
    final from = r * (rowLength + 1) + 1;
    final at = r * rowLength;
    for (var i = 0; i < rowLength; i++) {
      final raw = data[from + i];
      final left = i >= pixel ? out[at + i - pixel] : 0;
      final up = r > 0 ? out[at - rowLength + i] : 0;
      final corner = r > 0 && i >= pixel ? out[at - rowLength + i - pixel] : 0;
      out[at + i] = switch (filter) {
        0 => raw,
        1 => raw + left,
        2 => raw + up,
        3 => raw + ((left + up) >> 1),
        4 => raw + _paeth(left, up, corner),
        _ => throw const FormatException('Bad PNG predictor row.'),
      };
    }
  }
  return out;
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

int _find(Uint8List bytes, String text, int from) {
  final codes = text.codeUnits;
  outer:
  for (var i = from; i <= bytes.length - codes.length; i++) {
    for (var j = 0; j < codes.length; j++) {
      if (bytes[i + j] != codes[j]) continue outer;
    }
    return i;
  }
  return -1;
}

/// Reads PDF syntax: ISO 32000-1, section 7.2 and 7.3.
class _Reader {
  _Reader(this.bytes, this.pos);

  final Uint8List bytes;
  int pos;

  static bool _white(int c) => c == 0 || c == 9 || c == 10 || c == 12 || c == 13 || c == 32;

  static bool _delimiter(int c) =>
      c == 0x28 || // (
      c == 0x29 || // )
      c == 0x3C || // <
      c == 0x3E || // >
      c == 0x5B || // [
      c == 0x5D || // ]
      c == 0x7B || // {
      c == 0x7D || // }
      c == 0x2F || // /
      c == 0x25; // %

  void skipSpace() {
    while (pos < bytes.length) {
      final c = bytes[pos];
      if (_white(c)) {
        pos++;
      } else if (c == 0x25) {
        while (pos < bytes.length && bytes[pos] != 0x0A && bytes[pos] != 0x0D) {
          pos++;
        }
      } else {
        return;
      }
    }
  }

  bool startsWith(String text) {
    if (pos + text.length > bytes.length) return false;
    for (var i = 0; i < text.length; i++) {
      if (bytes[pos + i] != text.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// A keyword or number, or null at a delimiter or the end.
  String? word() {
    skipSpace();
    final start = pos;
    while (pos < bytes.length && !_white(bytes[pos]) && !_delimiter(bytes[pos])) {
      pos++;
    }
    return pos == start ? null : latin1.decode(Uint8List.sublistView(bytes, start, pos));
  }

  static final _whole = RegExp(r'^\d+$');

  Object value() {
    skipSpace();
    if (pos >= bytes.length) throw const FormatException('Unexpected end.');
    final c = bytes[pos];
    if (c == 0x2F) {
      pos++;
      final start = pos;
      while (pos < bytes.length && !_white(bytes[pos]) && !_delimiter(bytes[pos])) {
        pos++;
      }
      return _Name(latin1.decode(Uint8List.sublistView(bytes, start, pos)));
    }
    if (c == 0x28) return _literal();
    if (c == 0x3C) {
      if (pos + 1 < bytes.length && bytes[pos + 1] == 0x3C) {
        pos += 2;
        final entries = <String, Object>{};
        while (true) {
          skipSpace();
          if (startsWith('>>')) {
            pos += 2;
            return _Dict(entries);
          }
          final key = value();
          if (key is! _Name) throw const FormatException('Dictionary key is not a name.');
          entries[key.raw] = value();
        }
      }
      return _hex();
    }
    if (c == 0x5B) {
      pos++;
      final items = <Object>[];
      while (true) {
        skipSpace();
        if (pos < bytes.length && bytes[pos] == 0x5D) {
          pos++;
          return items;
        }
        items.add(value());
      }
    }
    final text = word();
    if (text == null) throw FormatException('Unexpected byte $c at $pos.');
    if (_whole.hasMatch(text)) {
      final before = pos;
      final second = word();
      if (second != null && _whole.hasMatch(second) && word() == 'R') {
        return _Ref(int.parse(text), int.parse(second));
      }
      pos = before;
    }
    return _Raw(text);
  }

  _Str _literal() {
    pos++;
    final out = BytesBuilder(copy: false);
    var depth = 1;
    while (pos < bytes.length) {
      final c = bytes[pos++];
      if (c == 0x5C) {
        if (pos >= bytes.length) break;
        final e = bytes[pos++];
        switch (e) {
          case 0x6E:
            out.addByte(0x0A);
          case 0x72:
            out.addByte(0x0D);
          case 0x74:
            out.addByte(0x09);
          case 0x62:
            out.addByte(0x08);
          case 0x66:
            out.addByte(0x0C);
          case 0x0D:
            if (pos < bytes.length && bytes[pos] == 0x0A) pos++;
          case 0x0A:
            break;
          default:
            if (e >= 0x30 && e <= 0x37) {
              var n = e - 0x30;
              for (var i = 0; i < 2 && pos < bytes.length; i++) {
                final d = bytes[pos];
                if (d < 0x30 || d > 0x37) break;
                n = n * 8 + d - 0x30;
                pos++;
              }
              out.addByte(n & 0xFF);
            } else {
              out.addByte(e);
            }
        }
      } else if (c == 0x28) {
        depth++;
        out.addByte(c);
      } else if (c == 0x29) {
        if (--depth == 0) return _Str(out.takeBytes());
        out.addByte(c);
      } else if (c == 0x0D) {
        // An end of line inside a string reads as a line feed, whichever it was.
        if (pos < bytes.length && bytes[pos] == 0x0A) pos++;
        out.addByte(0x0A);
      } else {
        out.addByte(c);
      }
    }
    throw const FormatException('Unclosed string.');
  }

  _Str _hex() {
    pos++;
    final out = BytesBuilder(copy: false);
    int? high;
    while (pos < bytes.length) {
      final c = bytes[pos++];
      if (c == 0x3E) {
        if (high != null) out.addByte(high << 4);
        return _Str(out.takeBytes());
      }
      if (_white(c)) continue;
      final digit = switch (c) {
        >= 0x30 && <= 0x39 => c - 0x30,
        >= 0x41 && <= 0x46 => c - 0x37,
        >= 0x61 && <= 0x66 => c - 0x57,
        _ => throw const FormatException('Bad hex string.'),
      };
      if (high == null) {
        high = digit;
      } else {
        out.addByte(high << 4 | digit);
        high = null;
      }
    }
    throw const FormatException('Unclosed hex string.');
  }
}

class _Writer {
  final _out = BytesBuilder(copy: false);

  int get length => _out.length;

  void text(String s) => _out.add(latin1.encode(s));

  void bytes(Uint8List b) => _out.add(b);

  Uint8List result() => _out.takeBytes();
}

const _hexDigits = '0123456789abcdef';

String _hexOf(Uint8List bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out
      ..write(_hexDigits[b >> 4])
      ..write(_hexDigits[b & 15]);
  }
  return out.toString();
}

/// Writes [value], encrypting every string. A signature's /Contents stays as it is, as the standard
/// asks: it holds the signature itself, which readers check without decrypting.
void _write(_Writer out, Object value, _Lock lock) {
  switch (value) {
    case _Name():
      out.text('/${value.raw}');
    case _Raw():
      out.text(value.text);
    case _Ref():
      out.text('${value.number} ${value.generation} R');
    case _Str():
      out.text('<${_hexOf(lock.encrypt(value.bytes))}>');
    case List():
      out.text('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.text(' ');
        _write(out, value[i], lock);
      }
      out.text(']');
    case _Dict():
      final signature = value.entries.containsKey('ByteRange');
      out.text('<<');
      for (final MapEntry(:key, :value) in value.entries.entries) {
        out.text(' /$key ');
        if (signature && key == 'Contents' && value is _Str) {
          out.text('<${_hexOf(value.bytes)}>');
        } else {
          _write(out, value, lock);
        }
      }
      out.text(' >>');
    default:
      throw FormatException('Can\'t write $value.');
  }
}
