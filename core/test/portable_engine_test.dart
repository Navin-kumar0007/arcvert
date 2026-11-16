import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

img.Image picture({int width = 640, int height = 480, int channels = 3}) {
  final image = img.Image(width: width, height: height, numChannels: channels);
  for (final pixel in image) {
    pixel
      ..r = pixel.x * 255 ~/ width
      ..g = pixel.y * 255 ~/ height
      ..b = (pixel.x * pixel.y) % 256;
    if (channels == 4) pixel.a = 255;
  }
  return image;
}

/// A JPEG with EXIF saying "rotate 90 degrees" and a GPS tag, like a phone photo.
Uint8List phonePhoto() {
  final jpeg = img.encodeJpg(picture());
  final tiff = BytesBuilder();
  void u16(int value) => tiff.add([value & 0xFF, value >> 8]);
  void u32(int value) => tiff.add([for (var i = 0; i < 4; i++) (value >> (8 * i)) & 0xFF]);
  tiff.add(ascii.encode('II*\u0000'));
  u32(8);
  u16(2);
  u16(0x112);
  u16(3);
  u32(1);
  u16(6);
  u16(0);
  u16(0x8825);
  u16(4);
  u32(1);
  u32(38);
  u32(0);
  u16(1);
  u16(1);
  u16(2);
  u32(2);
  tiff.add(ascii.encode('N\u0000\u0000\u0000'));
  u32(0);
  final body = [...ascii.encode('Exif\u0000\u0000'), ...tiff.takeBytes()];
  final length = body.length + 2;
  return Uint8List.fromList([
    ...jpeg.sublist(0, 2),
    0xFF,
    0xE1,
    length >> 8,
    length & 0xFF,
    ...body,
    ...jpeg.sublist(2),
  ]);
}

Future<PortableFile> run(
  String id,
  Uint8List bytes, {
  String name = 'photo.jpg',
  ActionOptions options = const ActionOptions(),
}) async {
  final outputs = await runPortable(actionById(id)!, [PortableFile(name, bytes)], options: options);
  return outputs.single;
}

FileKind kind(PortableFile file) => detectKind(file.bytes, fileName: file.name);

bool containsAscii(Uint8List bytes, String text) => latin1.decode(bytes).contains(text);

void main() {
  final jpg = img.encodeJpg(picture());
  final png = img.encodePng(picture());

  group('which actions run everywhere', () {
    final portable = actionCatalogue.where(
      (action) => action.accepts.any((kind) => canRunPortably(action, kind)),
    );

    test('images, subtitles and archives do, and nothing else', () {
      for (final action in portable) {
        final families = action.accepts.map((kind) => kind.family).toSet();
        expect(
          families.intersection({FileFamily.image, FileFamily.subtitle, FileFamily.archive}),
          isNotEmpty,
          reason: action.id,
        );
      }
    });

    test('there are about thirty', () {
      expect(portable.length, inInclusiveRange(25, 35));
    });

    test('formats it cannot read or write are left out', () {
      expect(canRunPortably(actionById('image-to-png')!, FileKind.heic), isFalse);
      expect(canRunPortably(actionById('image-to-png')!, FileKind.avif), isFalse);
      expect(canRunPortably(actionById('image-to-png')!, FileKind.svg), isFalse);
      expect(canRunPortably(actionById('image-to-avif')!, FileKind.jpg), isFalse);
      expect(canRunPortably(actionById('video-to-mp3')!, FileKind.mp4), isFalse);
      expect(canRunPortably(actionById('pdf-merge')!, FileKind.pdf), isFalse);
    });

    test('every portable action really runs on a JPG, an SRT or a ZIP', () async {
      const srt = '1\n00:00:01,000 --> 00:00:02,000\nHi\n';
      const options = ActionOptions(
        crop: (left: 0, top: 0, width: 10, height: 10),
        shift: Duration(seconds: 1),
        newPassword: 'x',
        form: FormTarget(width: 10, height: 10),
      );
      for (final action in portable) {
        final PortableFile file;
        if (action.accepts.contains(FileKind.srt)) {
          file = PortableFile('a.srt', utf8.encode(srt));
        } else if (action.accepts.contains(FileKind.zip)) {
          final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'x'));
          file = PortableFile('a.zip', ZipEncoder().encodeBytes(archive));
        } else {
          file = PortableFile('a.jpg', jpg);
        }
        final outputs = await runPortable(action, [file], options: options);
        expect(outputs.single.bytes, isNotEmpty, reason: action.id);
      }
    });
  });

  group('conversions', () {
    final expected = {
      'image-to-png': FileKind.png,
      'image-to-webp': FileKind.webp,
      'image-to-gif': FileKind.gif,
      'image-to-tiff': FileKind.tiff,
      'image-to-ico': FileKind.ico,
      'image-to-pdf': FileKind.pdf,
    };
    expected.forEach((id, output) {
      test(id, () async {
        final result = await run(id, jpg);
        expect(kind(result), output);
        expect(result.name, 'photo (converted).${output.extension}');
      });
    });

    test('PNG to JPG', () async {
      expect(kind(await run('image-to-jpg', png, name: 'a.png')), FileKind.jpg);
    });

    test('every readable format opens', () async {
      final sources = {
        'a.png': png,
        'a.jpg': jpg,
        'a.webp': img.encodeWebP(picture()),
        'a.gif': img.encodeGif(picture(), singleFrame: true),
        'a.bmp': img.encodeBmp(picture()),
        'a.tiff': img.encodeTiff(picture()),
        'a.ico': img.encodeIco(picture(width: 64, height: 64)),
      };
      for (final entry in sources.entries) {
        final out = await run('image-to-jpg', entry.value, name: entry.key);
        expect(kind(out), FileKind.jpg, reason: entry.key);
      }
    });

    test('the input bytes are not changed', () async {
      final copy = Uint8List.fromList(jpg);
      await run('image-to-png', copy);
      expect(copy, jpg);
    });

    test('a PNG called .jpg is treated as the PNG it is', () async {
      final result = await run('image-to-jpg', png, name: 'liar.jpg');
      expect(kind(result), FileKind.jpg);
      expect(result.name, 'liar (converted).jpg');
    });
  });

  group('privacy and rotation', () {
    final photo = phonePhoto();

    test('the test photo has what we need to remove', () {
      expect(containsAscii(photo, 'Exif'), isTrue);
      // The decoder applies the EXIF rotation itself, so a 640 x 480 file reads as tall.
      expect(img.decodeJpg(photo)!.width, 480);
    });

    for (final id in [
      'image-to-jpg',
      'image-to-png',
      'image-to-webp',
      'fit-whatsapp-photo',
      'fit-instagram',
      'image-compress',
      'image-strip-metadata',
      'image-rotate',
      'image-flip',
      'image-resize',
      'fit-image-100kb',
    ]) {
      test('$id leaves no EXIF', () async {
        final result = await run(id, photo);
        expect(containsAscii(result.bytes, 'Exif'), isFalse);
        final decoded = img.decodeImage(result.bytes)!;
        expect(decoded.exif.isEmpty, isTrue);
      });
    }

    test('the picture comes out upright', () async {
      final decoded = img.decodeImage((await run('image-to-png', photo)).bytes)!;
      expect(decoded.width, 480);
      expect(decoded.height, 640);
    });

    test('PDF pages are upright too and have no EXIF', () async {
      final result = await run('image-to-pdf', photo);
      expect(containsAscii(result.bytes, 'Exif'), isFalse);
      expect(latin1.decode(result.bytes), contains('/MediaBox [0 0 480.00 640.00]'));
    });
  });

  group('make it fit', () {
    test('WhatsApp: long side 1600 and JPG', () async {
      final big = img.encodeJpg(picture(width: 3200, height: 1600));
      final result = await run('fit-whatsapp-photo', big);
      final decoded = img.decodeImage(result.bytes)!;
      expect(kind(result), FileKind.jpg);
      expect(decoded.width, 1600);
      expect(decoded.height, 800);
      expect(result.name, 'photo (whatsapp).jpg');
    });

    test('WhatsApp never enlarges', () async {
      final decoded = img.decodeImage((await run('fit-whatsapp-photo', jpg)).bytes)!;
      expect(decoded.width, 640);
    });

    test('a tall picture limits its height', () async {
      final tall = img.encodeJpg(picture(width: 1000, height: 4000));
      final decoded = img.decodeImage((await run('fit-whatsapp-photo', tall)).bytes)!;
      expect(decoded.height, 1600);
      expect(decoded.width, 400);
    });

    test('Instagram is exactly 1080 x 1350, for wide and tall pictures', () async {
      for (final source in [picture(width: 2000, height: 500), picture(width: 500, height: 2000)]) {
        final result = await run('fit-instagram', img.encodeJpg(source));
        final decoded = img.decodeImage(result.bytes)!;
        expect('${decoded.width}x${decoded.height}', '1080x1350');
      }
    });

    test('web-ready is WebP with long side 1920', () async {
      final big = img.encodeJpg(picture(width: 3000, height: 1500));
      final result = await run('fit-web', big);
      expect(kind(result), FileKind.webp);
      expect(img.decodeImage(result.bytes)!.width, 1920);
    });

    test('under 100 KB really is, and stays a JPG', () async {
      final big = img.encodeJpg(picture(width: 2000, height: 1500), quality: 95);
      final result = await run('fit-image-100kb', big);
      expect(result.bytes.length, lessThanOrEqualTo(100 * 1024));
      expect(kind(result), FileKind.jpg);
      expect(result.name, 'photo (under 100 KB).jpg');
    });

    test('a PNG stays a PNG, by shrinking', () async {
      final big = img.encodePng(picture(width: 1500, height: 1500));
      final result = await run('fit-image-100kb', big, name: 'a.png');
      expect(result.bytes.length, lessThanOrEqualTo(100 * 1024));
      expect(kind(result), FileKind.png);
    });

    test('uses the best quality that fits', () async {
      final result = await run('fit-image-1mb', jpg);
      final atMax = img.encodeJpg(img.decodeImage(jpg)!, quality: 95);
      expect(result.bytes.length, atMax.length);
    });
  });

  group('tools', () {
    test('resize defaults to half', () async {
      final decoded = img.decodeImage((await run('image-resize', jpg)).bytes)!;
      expect('${decoded.width}x${decoded.height}', '320x240');
    });

    test('resize to a size, never enlarging', () async {
      Future<int> widthFor(int side) async {
        final out = await run('image-resize', jpg, options: ActionOptions(longSide: side));
        return img.decodeImage(out.bytes)!.width;
      }

      expect(await widthFor(100), 100);
      expect(await widthFor(5000), 640);
    });

    test('rotate swaps the sides', () async {
      final decoded = img.decodeImage((await run('image-rotate', png, name: 'a.png')).bytes)!;
      expect('${decoded.width}x${decoded.height}', '480x640');
    });

    test('rotate refuses other angles', () async {
      await expectLater(
        run('image-rotate', jpg, options: const ActionOptions(degrees: 45)),
        throwsA(isA<EngineFailed>()),
      );
    });

    test('flip mirrors the pixels', () async {
      final original = img.decodePng(png)!;
      final flipped = img.decodePng((await run('image-flip', png, name: 'a.png')).bytes)!;
      expect(flipped.getPixel(0, 0).r, original.getPixel(639, 0).r);
      final vertical = img.decodePng(
        (await run(
          'image-flip',
          png,
          name: 'a.png',
          options: const ActionOptions(flipVertical: true),
        )).bytes,
      )!;
      expect(vertical.getPixel(0, 0).g, original.getPixel(0, 479).g);
    });

    test('crop is exact', () async {
      final out = await run(
        'image-crop',
        jpg,
        options: const ActionOptions(crop: (left: 10, top: 20, width: 100, height: 50)),
      );
      final decoded = img.decodeImage(out.bytes)!;
      expect('${decoded.width}x${decoded.height}', '100x50');
    });

    test('a crop outside the picture is refused, not squeezed in', () async {
      await expectLater(
        run(
          'image-crop',
          jpg,
          options: const ActionOptions(crop: (left: 600, top: 0, width: 100, height: 50)),
        ),
        throwsA(isA<EngineFailed>()),
      );
    });

    test('crop without an area says so', () async {
      await expectLater(run('image-crop', jpg), throwsA(isA<EngineFailed>()));
    });

    test('compress makes a JPG smaller', () async {
      final big = img.encodeJpg(picture(width: 1200, height: 900), quality: 100);
      expect((await run('image-compress', big)).bytes.length, lessThan(big.length));
    });

    test('compress levels: best quality is larger, smallest is smaller', () async {
      final big = img.encodeJpg(picture(width: 1200, height: 900), quality: 100);
      Future<int> size(CompressLevel? level) async =>
          (await run('image-compress', big, options: ActionOptions(compress: level))).bytes.length;
      final high = await size(CompressLevel.high);
      final medium = await size(null);
      final small = await size(CompressLevel.small);
      expect(high, greaterThan(medium));
      expect(small, lessThan(medium));
    });

    test('best quality keeps a PNG\'s colours, so it says it can\'t be made smaller', () async {
      // PNG is lossless: without a palette there's nothing to give up, and Compress never hands
      // back a file as big or bigger.
      await expectLater(
        run(
          'image-compress',
          png,
          name: 'a.png',
          options: const ActionOptions(compress: CompressLevel.high),
        ),
        throwsA(isA<EngineFailed>().having((e) => e.key, 'key', 'pictureAsSmall')),
      );
    });

    test('a photo saved at high quality already is never made bigger', () async {
      final saved = img.encodeJpg(picture(width: 800, height: 600), quality: 70);
      await expectLater(
        run('image-compress', saved, options: const ActionOptions(compress: CompressLevel.high)),
        throwsA(isA<EngineFailed>().having((e) => e.key, 'key', 'pictureAsSmall')),
      );
    });

    test('compress reduces a PNG to a palette and still reads back', () async {
      final result = await run('image-compress', png, name: 'a.png');
      final decoded = img.decodePng(result.bytes)!;
      expect(decoded.hasPalette, isTrue);
      expect(decoded.width, 640);
    });
  });

  group('transparency', () {
    final clear = img.Image(width: 32, height: 32, numChannels: 4);

    test('transparent areas turn white in JPG, not black', () async {
      final result = await run('image-to-jpg', img.encodePng(clear), name: 'a.png');
      final pixel = img.decodeJpg(result.bytes)!.getPixel(5, 5);
      expect(pixel.r, greaterThan(250));
      expect(pixel.g, greaterThan(250));
      expect(pixel.b, greaterThan(250));
    });

    test('and in PDF pages', () async {
      final result = await run('image-to-pdf', img.encodePng(clear), name: 'a.png');
      expect(kind(result), FileKind.pdf);
    });

    test('PNG keeps its transparency', () async {
      final result = await run('image-resize', img.encodePng(clear), name: 'a.png');
      expect(img.decodePng(result.bytes)!.getPixel(1, 1).a, 0);
    });
  });

  group('batches and merges', () {
    test('one output per file, in order', () async {
      final outputs = await runPortable(actionById('image-to-webp')!, [
        PortableFile('a.jpg', jpg),
        PortableFile('b.png', png),
      ]);
      expect(outputs.map((file) => file.name), ['a (converted).webp', 'b (converted).webp']);
    });

    test('images to one PDF keeps every page', () async {
      final outputs = await runPortable(actionById('images-to-pdf')!, [
        PortableFile('a.jpg', jpg),
        PortableFile('b.png', png),
        PortableFile('c.jpg', jpg),
      ]);
      expect(outputs.single.name, 'a (combined).pdf');
      expect(latin1.decode(outputs.single.bytes), contains('/Count 3'));
    });

    test('progress rises to 1', () async {
      final seen = <double>[];
      await runPortable(actionById('image-to-png')!, [
        PortableFile('a.jpg', jpg),
        PortableFile('b.jpg', jpg),
      ], onProgress: seen.add);
      expect(seen, isNotEmpty);
      expect(seen.last, 1);
      expect(seen, everyElement(inInclusiveRange(0, 1)));
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });
  });

  group('subtitles', () {
    final srt = utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nनमस्ते\n');

    test('to VTT, text and back', () async {
      final vtt = await run('subtitle-to-vtt', srt, name: 'a.srt');
      expect(utf8.decode(vtt.bytes), startsWith('WEBVTT'));
      expect(vtt.name, 'a (converted).vtt');
      final text = await run('subtitle-to-text', srt, name: 'a.srt');
      expect(utf8.decode(text.bytes), 'नमस्ते\n');
      final back = await run('subtitle-to-srt', vtt.bytes, name: 'a.vtt');
      expect(utf8.decode(back.bytes), contains('00:00:01,000'));
    });

    test('shift keeps the format', () async {
      final shifted = await run(
        'subtitle-shift',
        srt,
        name: 'a.srt',
        options: const ActionOptions(shift: Duration(seconds: 1)),
      );
      expect(shifted.name, 'a (shifted).srt');
      expect(utf8.decode(shifted.bytes), contains('00:00:02,000'));
    });

    test('shift without an amount says so', () async {
      await expectLater(run('subtitle-shift', srt, name: 'a.srt'), throwsA(isA<EngineFailed>()));
    });

    test('text with no cues', () async {
      final blank = utf8.encode('WEBVTT\n\nNOTE nothing here\n');
      await expectLater(run('subtitle-to-srt', blank, name: 'a.vtt'), throwsA(isA<EngineFailed>()));
    });
  });

  group('bad files fail in plain words', () {
    Matcher plain(String words) {
      return throwsA(isA<EngineFailed>().having((e) => e.message, 'message', contains(words)));
    }

    test('wrong kind', () async {
      await expectLater(
        run('image-to-png', utf8.encode('text'), name: 'a.png'),
        plain("can't use"),
      );
    });

    test('a picture over the pixel limit is refused before decoding it', () async {
      final forged = Uint8List.fromList(jpg);
      var i = 2;
      while (forged[i + 1] != 0xC0) {
        i += 2 + (forged[i + 2] << 8 | forged[i + 3]);
      }
      const side = 15000;
      forged[i + 5] = side >> 8;
      forged[i + 6] = side & 0xFF;
      forged[i + 7] = side >> 8;
      forged[i + 8] = side & 0xFF;
      await expectLater(run('image-to-png', forged), plain('too large'));
    });

    test('the limit allows a 200 megapixel phone photo', () {
      expect(16320 * 12240, lessThan(maxPortablePixels));
    });

    test('a truncated JPEG', () async {
      final broken = jpg.sublist(0, 40);
      await expectLater(run('image-to-png', broken), plain('could not be read'));
    });

    test('random bytes after a PNG signature', () async {
      final broken = Uint8List.fromList([...png.sublist(0, 8), 1, 2, 3, 4]);
      await expectLater(run('image-to-jpg', broken, name: 'a.png'), plain('could not be read'));
    });

    test('merging one file', () async {
      const action = RadialAction(
        id: 'x',
        label: 'Join',
        mode: ActionMode.tools,
        engine: Engine.builtIn,
        accepts: {FileKind.jpg},
        suffix: 'x',
        minFiles: 2,
      );
      await expectLater(runPortable(action, [PortableFile('a.jpg', jpg)]), plain('at least 2'));
    });

    test('an animated GIF is not silently flattened to its first frame', () async {
      final first = picture(width: 16, height: 16);
      first.addFrame(picture(width: 16, height: 16));
      final animated = img.encodeGif(first);
      await expectLater(run('image-resize', animated, name: 'a.gif'), plain('Animated'));
    });

    test('an animated GIF can still become a still JPG', () async {
      final first = picture(width: 16, height: 16);
      first.addFrame(picture(width: 16, height: 16));
      final out = await run('image-to-jpg', img.encodeGif(first), name: 'a.gif');
      expect(kind(out), FileKind.jpg);
    });
  });

  group('a HEIC photo the platform has decoded', () {
    PortableFile decoded() => PortableFile('photo.heic', img.encodePng(picture()));

    test('can run what makes sense', () {
      for (final id in ['image-to-jpg', 'image-to-png', 'image-compress', 'image-rotate']) {
        expect(canRunDecoded(actionById(id)!, FileKind.heic), isTrue, reason: id);
      }
    });

    test('nothing else is treated this way', () {
      expect(canRunDecoded(actionById('image-to-png')!, FileKind.png), isFalse);
      expect(canRunDecoded(actionById('video-mute')!, FileKind.heic), isFalse);
      expect(canRunDecoded(actionById('image-to-avif')!, FileKind.heic), isFalse);
    });

    test('compressing makes a JPG rather than a huge PNG', () async {
      final out = (await runPortable(actionById('image-compress')!, [decoded()])).single;
      expect(out.name, 'photo (compressed).jpg');
      expect(detectKind(out.bytes), FileKind.jpg);
    });

    test('asking for PNG still makes one', () async {
      final out = (await runPortable(actionById('image-to-png')!, [decoded()])).single;
      expect(out.name, 'photo (converted).png');
      expect(detectKind(out.bytes), FileKind.png);
    });

    test('an ordinary PNG stays a PNG', () async {
      final png = PortableFile('photo.png', img.encodePng(picture()));
      final out = (await runPortable(actionById('image-compress')!, [png])).single;
      expect(detectKind(out.bytes), FileKind.png);
    });
  });

  group('form photos', () {
    final action = actionById('image-form')!;

    /// Like a photo: smooth colour with some grain.
    Uint8List photo({int width = 1600, int height = 1200}) {
      final image = img.Image(width: width, height: height);
      var state = 7;
      for (final pixel in image) {
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
        pixel
          ..r = (pixel.x * 255 ~/ width + state % 24).clamp(0, 255)
          ..g = (pixel.y * 255 ~/ height + (state >> 8) % 24).clamp(0, 255)
          ..b = 120 + (state >> 16) % 24;
      }
      return img.encodeJpg(image, quality: 95);
    }

    /// Like a signature: a thin dark line on white, which compresses to almost nothing.
    Uint8List signature() {
      final image = img.Image(width: 900, height: 400);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawLine(image, x1: 40, y1: 300, x2: 860, y2: 100, color: img.ColorRgb8(0, 0, 0));
      return img.encodePng(image);
    }

    /// Like a phone photo of a signed page: grey, uneven paper with grain, a blue signature in
    /// the middle and lots of empty paper around it.
    Uint8List signedPage({bool ink = true}) {
      final image = img.Image(width: 1200, height: 900);
      var state = 3;
      for (final pixel in image) {
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
        final shade = 205 + pixel.x * 20 ~/ 1200 + state % 10;
        pixel
          ..r = shade
          ..g = shade
          ..b = shade - 6;
      }
      if (ink) {
        for (var t = 0; t < 4; t++) {
          img.drawLine(
            image,
            x1: 420,
            y1: 470 + t,
            x2: 780,
            y2: 400 + t,
            color: img.ColorRgb8(30, 40, 150),
          );
          img.drawLine(
            image,
            x1: 500 + t,
            y1: 380,
            x2: 560 + t,
            y2: 500,
            color: img.ColorRgb8(30, 40, 150),
          );
        }
      }
      return img.encodeJpg(image, quality: 92);
    }

    Future<Uint8List> run(Uint8List input, FormTarget form, {ActionOptions? extra}) async {
      final out = await runPortable(action, [
        PortableFile('me.jpg', input),
      ], options: ActionOptions(form: form, crop: extra?.crop));
      expect(out.single.name, 'me (form).jpg');
      return out.single.bytes;
    }

    group('signature cleanup', () {
      test('crops to the ink, whitens the paper and keeps blue ink blue', () async {
        final bytes = await run(
          signedPage(),
          FormTarget(
            width: 140,
            height: 60,
            minBytes: formMinBytes(10),
            maxBytes: formMaxBytes(20),
            signature: true,
          ),
        );
        final out = img.decodeJpg(bytes)!;
        expect((out.width, out.height), (140, 60));
        expect(bytes.length, inInclusiveRange(10 * 1024, 20000));
        // The paper is white now, corners and edges included.
        for (final (x, y) in [(0, 0), (139, 0), (0, 59), (139, 59), (70, 1)]) {
          expect(out.getPixel(x, y).r, greaterThan(240), reason: '($x, $y)');
        }
        // The signature fills the width, so the empty paper around it was cropped away.
        var leftmost = 140, rightmost = -1, blueish = 0, dark = 0;
        for (final pixel in out) {
          if (pixel.r < 120) {
            dark++;
            leftmost = math.min(leftmost, pixel.x);
            rightmost = math.max(rightmost, pixel.x);
            if (pixel.b > pixel.r + 20) blueish++;
          }
        }
        expect(dark, greaterThan(20));
        expect(rightmost - leftmost, greaterThan(90));
        expect(blueish, greaterThan(dark ~/ 2));
      });

      test('nothing is cut from the signature, whatever the form\'s shape', () {
        final page = img.decodeJpg(signedPage())!;
        final cleaned = cleanSignature(page);
        // The ink ran from x 420 to 780 and y 380 to 500, with a margin kept around it.
        expect(cleaned.width, inInclusiveRange(360, 460));
        expect(cleaned.height, inInclusiveRange(120, 220));
      });

      test('a signature framed tightly, so ink is a large share, still cleans up', () {
        final page = img.decodeJpg(signedPage())!;
        final tight = img.copyCrop(page, x: 410, y: 370, width: 380, height: 140);
        final cleaned = cleanSignature(tight);
        var white = 0;
        for (final pixel in cleaned) {
          if (pixel.r > 240 && pixel.g > 240) white++;
        }
        expect(white, greaterThan(cleaned.width * cleaned.height ~/ 2));
      });

      test('black ink on white paper, as a scanner makes it', () async {
        final bytes = await run(
          signature(),
          const FormTarget(width: 300, height: 80, signature: true),
        );
        final out = img.decodeJpg(bytes)!;
        expect((out.width, out.height), (300, 80));
        var darkest = 255;
        for (final pixel in out) {
          darkest = math.min(darkest, pixel.r.toInt());
        }
        // A one-pixel pen line, shrunk to a third, still reads as ink.
        expect(darkest, lessThan(110));
      });

      test('a page with no signature says so', () async {
        expect(
          () => run(
            signedPage(ink: false),
            const FormTarget(width: 140, height: 60, signature: true),
          ),
          throwsA(isA<EngineFailed>().having((e) => e.key, 'key', 'noSignature')),
        );
      });

      test('photos are never cleaned up', () async {
        final plain = await run(
          photo(width: 400, height: 400),
          const FormTarget(width: 100, height: 100),
        );
        final out = img.decodeJpg(plain)!;
        // A photo's colours stay as they were: nothing is pushed to white.
        expect(out.getPixel(50, 50).r, lessThan(240));
      });
    });

    test('the job form photo, exact and within limits', () async {
      final bytes = await run(
        photo(),
        FormTarget(width: 200, height: 230, minBytes: formMinBytes(20), maxBytes: formMaxBytes(50)),
      );
      final out = img.decodeJpg(bytes)!;
      expect((out.width, out.height), (200, 230));
      expect(bytes.length, inInclusiveRange(20 * 1024, 50 * 1000));
    });

    test(
      'a signature too plain to reach the minimum is brought up to it, still a picture',
      () async {
        final bytes = await run(
          signature(),
          FormTarget(
            width: 140,
            height: 60,
            minBytes: formMinBytes(10),
            maxBytes: formMaxBytes(20),
          ),
        );
        expect(bytes.length, inInclusiveRange(10 * 1024, 20 * 1000));
        expect(detectKind(bytes), FileKind.jpg);
        final out = img.decodeJpg(bytes)!;
        expect((out.width, out.height), (140, 60));
        expect(out.getPixel(0, 0).r, greaterThan(240), reason: 'The picture itself is unchanged');
      },
    );

    test('a very large minimum needs many comments, and still reads', () async {
      final bytes = await run(signature(), const FormTarget(minBytes: 200000));
      expect(bytes.length, greaterThanOrEqualTo(200000));
      expect(img.decodeJpg(bytes), isNotNull);
    });

    test('a picture already over the minimum gets nothing added', () async {
      final plain = await run(photo(width: 400, height: 400), const FormTarget());
      final same = await run(photo(width: 400, height: 400), const FormTarget(minBytes: 100));
      expect(same, plain);
    });

    test('no pixel size: the shape stays, and it fits', () async {
      final bytes = await run(photo(), FormTarget(maxBytes: formMaxBytes(50)));
      final out = img.decodeJpg(bytes)!;
      expect(out.width / out.height, closeTo(1600 / 1200, 0.01));
      expect(bytes.length, lessThanOrEqualTo(50000));
    });

    test('no pixel size: a huge photo is brought down', () async {
      final bytes = await run(photo(width: 3000, height: 2000), const FormTarget());
      expect(img.decodeJpg(bytes)!.width, 1200);
    });

    test('the crop chosen is what gets used', () async {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(image, x1: 50, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(0, 0, 255));
      final bytes = await run(
        img.encodePng(image),
        const FormTarget(width: 20, height: 20),
        extra: const ActionOptions(crop: (left: 60, top: 10, width: 30, height: 30)),
      );
      final pixel = img.decodeJpg(bytes)!.getPixel(10, 10);
      expect(pixel.b, greaterThan(200));
      expect(pixel.r, lessThan(60));
    });

    test('without a crop it takes the middle, not stretching the face', () async {
      final image = img.Image(width: 300, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(image, x1: 100, y1: 0, x2: 199, y2: 99, color: img.ColorRgb8(0, 0, 255));
      final bytes = await run(img.encodePng(image), const FormTarget(width: 50, height: 50));
      final out = img.decodeJpg(bytes)!;
      expect(out.getPixel(2, 25).b, greaterThan(200));
      expect(out.getPixel(47, 25).b, greaterThan(200));
    });

    test('transparency becomes white', () async {
      final image = img.Image(width: 20, height: 20, numChannels: 4);
      final bytes = await run(img.encodePng(image), const FormTarget(width: 20, height: 20));
      expect(img.decodeJpg(bytes)!.getPixel(5, 5).r, greaterThan(240));
    });

    test('what a photo says about where it was taken does not come along', () async {
      final image = img.Image(width: 500, height: 500);
      image.exif.gpsIfd['GPSLatitude'] = [28, 36, 50];
      final bytes = await run(img.encodeJpg(image), const FormTarget(width: 100, height: 100));
      expect(img.decodeJpg(bytes)!.exif.gpsIfd.isEmpty, isTrue);
    });

    test('impossible limits say so, in words', () async {
      await expectLater(
        run(photo(), const FormTarget(width: 1600, height: 1200, maxBytes: 100)),
        throwsA(
          isA<EngineFailed>().having((e) => e.message, 'message', contains('too much detail')),
        ),
      );
    });

    test('limits the wrong way round say so', () async {
      await expectLater(
        run(photo(), const FormTarget(minBytes: 200, maxBytes: 100)),
        throwsA(isA<EngineFailed>().having((e) => e.message, 'message', contains('more than'))),
      );
    });

    test('half a pixel size says so', () async {
      await expectLater(run(photo(), const FormTarget(width: 100)), throwsA(isA<EngineFailed>()));
    });

    test('needing to be told what the form wants', () async {
      await expectLater(
        runPortable(action, [PortableFile('me.jpg', photo())]),
        throwsA(isA<EngineFailed>()),
      );
    });

    test('the original is only read', () async {
      final input = photo(width: 300, height: 300);
      final before = Uint8List.fromList(input);
      await run(input, const FormTarget(width: 50, height: 50));
      expect(input, before);
    });
  });

  group('scanned document', () {
    final action = actionById('images-scan-pdf')!;

    /// Like a phone photo of a printed page: warm grey paper, uneven light, rows of dark text.
    Uint8List page(int seed) {
      final image = img.Image(width: 1500, height: 2000);
      var state = seed;
      for (final pixel in image) {
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
        final shade = 190 + pixel.y * 30 ~/ 2000 + state % 12;
        pixel
          ..r = shade + 4
          ..g = shade
          ..b = shade - 10;
      }
      for (var row = 0; row < 40; row++) {
        for (var word = 0; word < 9; word++) {
          img.fillRect(
            image,
            x1: 120 + word * 140,
            y1: 150 + row * 44,
            x2: 120 + word * 140 + 90 + (row * 7 + word * 13) % 30,
            y2: 150 + row * 44 + 14,
            color: img.ColorRgb8(40, 38, 35),
          );
        }
      }
      return img.encodeJpg(image, quality: 90);
    }

    test('is Make it fit, combines pages, and offers smaller limits on its ring', () {
      expect(action.isFit, isTrue);
      expect(combinesFiles(action), isTrue);
      expect(keepsOrder(action), isTrue);
      final ring = ringChoices(action);
      expect(ring.map((choice) => choice.label), ['Under 1 MB', 'Under 500 KB', 'Under 200 KB']);
      expect(ring.first.options.targetMb, isNull);
    });

    test('three pages become one PDF under 1 MB, printing at A4 size', () async {
      final out = await runPortable(action, [
        for (var i = 1; i <= 3; i++) PortableFile('page$i.jpg', page(i)),
      ]);
      expect(out.single.name, 'page1 (scan).pdf');
      final pdf = out.single.bytes;
      expect(pdf.length, lessThanOrEqualTo(1000 * 1000));
      final text = latin1.decode(pdf);
      expect(text, startsWith('%PDF'));
      expect(text, contains('/Count 3'));
      expect(text, contains('842.00]'));
    });

    test('a smaller limit from the ring is kept', () async {
      final out = await runPortable(action, [
        PortableFile('page.jpg', page(9)),
      ], options: const ActionOptions(targetMb: 0.2));
      expect(out.single.bytes.length, lessThanOrEqualTo(200 * 1000));
    });

    test('a limit no readable page could meet says so', () async {
      expect(
        () => runPortable(action, [
          PortableFile('page.jpg', page(4)),
        ], options: const ActionOptions(targetMb: 0.002)),
        throwsA(isA<EngineFailed>().having((e) => e.key, 'key', 'scanTooBig')),
      );
    });

    test('a cleaned page has white paper and black print', () {
      final cleaned = cleanPage(img.decodeJpg(page(5))!);
      expect(cleaned.getPixel(40, 40).r, 255);
      expect(cleaned.getPixel(1450, 1950).r, 255);
      expect(cleaned.getPixel(150, 157).r, lessThan(40));
      expect(cleaned.getPixel(150, 157).r, cleaned.getPixel(150, 157).b);
    });
  });

  group('photo details', () {
    /// Like a phone photo: when and with what it was taken, where, and the camera's serial number.
    Uint8List detailed() {
      final image = img.Image(width: 400, height: 300);
      image.exif.imageIfd['Make'] = img.IfdValueAscii('Pixel');
      image.exif.imageIfd['Model'] = img.IfdValueAscii('Pixel 9');
      image.exif.exifIfd[0x9003] = img.IfdValueAscii('2026:11:16 09:30:00');
      image.exif.exifIfd[0xA431] = img.IfdValueAscii('SERIAL-123');
      image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(28, 1);
      return img.encodeJpg(image);
    }

    img.ExifData detailsOf(Uint8List bytes) => img.decodeJpg(bytes)!.exif;

    test('the sample has what a phone writes', () {
      final exif = detailsOf(detailed());
      expect(exif.gpsIfd.isEmpty, isFalse);
      expect(exif.exifIfd[0xA431], isNotNull);
    });

    for (final id in ['image-to-jpg', 'image-compress', 'image-rotate', 'image-resize']) {
      test('$id keeps when and with what, never where or the serial number', () async {
        final exif = detailsOf((await run(id, detailed(), name: 'photo.png')).bytes);
        expect(exif.imageIfd['Model']?.toString(), contains('Pixel 9'));
        expect(exif.exifIfd[0x9003]?.toString(), contains('2026:11:16'));
        expect(exif.gpsIfd.isEmpty, isTrue);
        expect(exif.exifIfd[0xA431], isNull);
      });
    }

    for (final id in ['fit-whatsapp-photo', 'fit-image-100kb', 'image-strip-metadata']) {
      test('$id keeps no details at all', () async {
        final result = await run(id, detailed());
        expect(img.decodeImage(result.bytes)!.exif.isEmpty, isTrue);
      });
    }

    test('which actions keep details', () {
      expect(keepsPhotoDetails(actionById('image-to-png')!), isTrue);
      expect(keepsPhotoDetails(actionById('image-crop')!), isTrue);
      expect(keepsPhotoDetails(actionById('image-form')!), isFalse);
      expect(keepsPhotoDetails(actionById('fit-email-image')!), isFalse);
      expect(keepsPhotoDetails(actionById('image-strip-metadata')!), isFalse);
    });
  });
}
