import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

/// qpdf is a second, independent reader: if it opens the result with the password and finds it
/// sound, so will others. Skipped where it isn't installed.
final String? _qpdf = () {
  final found = Process.runSync('which', ['qpdf']);
  return found.exitCode == 0 ? (found.stdout as String).trim() : null;
}();

late Directory _folder;

String _put(String name, List<int> bytes) {
  final path = '${_folder.path}/$name';
  File(path).writeAsBytesSync(bytes);
  return path;
}

ProcessResult _run(List<String> args) => Process.runSync(_qpdf!, args);

/// A PDF written by hand: a literal string with escapes, an indirect /Length, and an update
/// appended after it that replaces one object and removes another.
Uint8List _handWritten() {
  final out = BytesBuilder();
  final offsets = <int, int>{};
  void add(String s) => out.add(latin1.encode(s));
  void obj(int n, String body) {
    offsets[n] = out.length;
    add('$n 0 obj\n$body\nendobj\n');
  }

  int table(List<int> numbers, String trailer) {
    final at = out.length;
    add('xref\n0 1\n0000000000 65535 f\r\n');
    for (final n in numbers) {
      final place = offsets[n];
      add('$n 1\n');
      add(place == null ? '0000000000 00001 f\r\n' : '${'$place'.padLeft(10, '0')} 00000 n\r\n');
    }
    add('trailer\n$trailer\nstartxref\n$at\n%%EOF\n');
    return at;
  }

  add('%PDF-1.4\n');
  obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
  obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  obj(
    3,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>',
  );
  const content = 'BT /F1 12 Tf 10 10 Td (Hi) Tj ET';
  obj(4, '<< /Length 5 0 R >>\nstream\n$content\nendstream');
  obj(5, '${content.length}');
  obj(6, '<< /Title (Old) >>');
  obj(7, '<< /Unused true >>');
  final firstTable = table([1, 2, 3, 4, 5, 6, 7], '<< /Size 8 /Root 1 0 R /Info 6 0 R >>');
  obj(6, r'<< /Title (Tea \(green\)\n\101\\ done) /Producer <48 69 7> >>');
  offsets.remove(7);
  table([6, 7], '<< /Size 8 /Root 1 0 R /Info 6 0 R /Prev $firstTable >>');
  return out.toBytes();
}

Uint8List _photoPdf() {
  final photo = img.Image(width: 40, height: 30);
  img.fill(photo, color: img.ColorRgb8(200, 90, 20));
  return buildImagePdf([img.encodeJpg(photo), img.encodeJpg(photo)]);
}

void main() {
  setUp(() => _folder = Directory.systemTemp.createTempSync('pdf-lock-'));
  tearDown(() => _folder.deleteSync(recursive: true));

  test('the result says AES-256 and holds nothing readable', () {
    final locked = latin1.decode(lockPdf(_handWritten(), 'secret'));
    expect(locked, startsWith('%PDF-1.7'));
    expect(locked, contains('/V 5 /R 6'));
    expect(locked, contains('/CFM /AESV3'));
    expect(locked, contains('/Extensions << /ADBE'));
    expect(locked, isNot(contains('Tea')));
    expect(locked, isNot(contains('BT /F1')));
    expect(locked, isNot(contains('/Unused')));
  });

  test('every lock is different, even with the same password', () {
    final pdf = _handWritten();
    expect(lockPdf(pdf, 'same'), isNot(equals(lockPdf(pdf, 'same'))));
  });

  test('an encrypted PDF or something else is refused, for PDFium\'s copy to be given', () {
    final locked = File('../test-files/locked.pdf').readAsBytesSync();
    expect(() => lockPdf(locked, 'x'), throwsFormatException);
    expect(() => lockPdf(Uint8List.fromList(utf8.encode('hello')), 'x'), throwsFormatException);
    final cut = _handWritten();
    expect(
      () => lockPdf(Uint8List.sublistView(cut, 0, cut.length - 300), 'x'),
      throwsFormatException,
    );
  });

  group('qpdf opens it', () {
    void check(Uint8List pdf, String password, {int pages = 1}) {
      final path = _put('locked.pdf', lockPdf(pdf, password, random: Random(7)));
      expect(_run(['--is-encrypted', path]).exitCode, 0);
      final shown = _run(['--password=$password', '--show-encryption', path]);
      expect(shown.stdout, contains('R = 6'));
      expect(shown.stdout, contains('stream encryption method: AESv3'));
      final checked = _run(['--password=$password', '--check', path]);
      expect(checked.exitCode, 0, reason: '${checked.stdout}${checked.stderr}');
      expect(checked.stdout, isNot(contains('WARNING')));
      final count = _run(['--password=$password', '--show-npages', path]);
      expect((count.stdout as String).trim(), '$pages');
      expect(_run(['--password=wrong', '--check', path]).exitCode, 2);
      expect(_run(['--check', path]).exitCode, 2);
    }

    test('a hand-written PDF with an update, keeping its strings and text', () {
      check(_handWritten(), 'secret');
      final path = _put('again.pdf', lockPdf(_handWritten(), 'secret'));
      final info = _run(['--password=secret', '--show-object=6', path]).stdout as String;
      expect(info, contains(r'(Tea \(green\)\nA\\ done)'));
      expect(info, contains('/Producer (Hip)'));
      final page = _run(['--password=secret', '--show-object=4', '--filtered-stream-data', path]);
      expect(page.stdout, 'BT /F1 12 Tf 10 10 Td (Hi) Tj ET');
    });

    test(
      'bytes before the header, and a table entry in use at offset 0, as some writers leave',
      () {
        final pdf = latin1
            .decode(_handWritten())
            .replaceFirst('0000000000 00001 f', '0000000000 00000 n');
        check(Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x0A, ...latin1.encode(pdf)]), 'secret');
      },
    );

    test('a photo PDF made here', () => check(_photoPdf(), 'secret', pages: 2));

    test('object streams, a cross-reference stream and linearization', () {
      final source = _put('source.pdf', _photoPdf());
      final packed = '${_folder.path}/packed.pdf';
      expect(_run(['--object-streams=generate', '--linearize', source, packed]).exitCode, 0);
      check(File(packed).readAsBytesSync(), 'secret', pages: 2);
    });

    test('a scanner app\'s PDF', () {
      check(File('../test-files/scan-with-stamp.pdf').readAsBytesSync(), 'secret');
    });

    test('a password in Hindi, and one past 127 bytes, which readers cut short too', () {
      check(_handWritten(), 'पासवर्ड १२३');
      final long = 'a' * 130;
      final path = _put('long.pdf', lockPdf(_handWritten(), long));
      expect(_run(['--password=${'a' * 127}', '--check', path]).exitCode, 0);
    });
  }, skip: _qpdf == null ? 'qpdf is not installed' : null);
}
