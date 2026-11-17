import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

const _college = MyFit(
  id: 'my-fit-abc123',
  name: 'College form',
  form: FormTarget(width: 200, height: 230, minBytes: 20480, maxBytes: 50000),
);

/// Like a photo: smooth colour with some grain, so it doesn't shrink to nothing.
Uint8List _photo({int width = 1600, int height = 1200}) {
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

void main() {
  group('kept in the settings', () {
    test('comes back as it went', () {
      const signature = MyFit(
        id: 'my-fit-z9',
        name: 'Bank signature',
        form: FormTarget(width: 140, height: 60, maxBytes: 20000, signature: true),
      );
      for (final fit in [_college, signature]) {
        expect(MyFit.fromJson(fit.toJson()), fit);
      }
    });

    test('leaves out what it does not have', () {
      const any = MyFit(id: 'my-fit-1', name: 'Any', form: FormTarget(maxBytes: 100000));
      expect(any.toJson(), {'id': 'my-fit-1', 'name': 'Any', 'maxBytes': 100000});
    });

    test('damaged ones read as nothing', () {
      final good = _college.toJson();
      for (final bad in <Object?>[
        null,
        'College form',
        {...good, 'id': 'image-form'},
        {...good, 'id': 7},
        {...good, 'name': '  '},
        {...good, 'name': 'x' * 31},
        {...good, 'height': null},
        {...good, 'minBytes': 60000},
      ]) {
        expect(MyFit.fromJson(bad), isNull, reason: '$bad');
      }
    });

    test('a nonsense number is left out rather than kept', () {
      final fit = MyFit.fromJson({..._college.toJson(), 'maxBytes': -5})!;
      expect(fit.form.maxBytes, isNull);
      expect(fit.form.minBytes, 20480);
    });
  });

  group('ids', () {
    test('are new each time, even made in the same moment', () {
      final now = DateTime.utc(2026, 11, 17);
      final first = newMyFitId(const [], now: now);
      final second = newMyFitId([first], now: now);
      expect(isMyFitId(first), isTrue);
      expect(isMyFitId(second), isTrue);
      expect(second, isNot(first));
    });

    test('never look like a catalogue action', () {
      for (final action in actionCatalogue) {
        expect(isMyFitId(action.id), isFalse, reason: action.id);
      }
    });
  });

  group('the word in the result name', () {
    test('is the name, as file names can hold it', () {
      expect(myFitSuffix('College form'), 'college form');
      expect(myFitSuffix('  NEET   photo '), 'neet photo');
      expect(myFitSuffix('Form: 2027/28 (final)'), 'form 2027 28 final');
      expect(myFitSuffix('हस्ताक्षर'), 'हस्ताक्षर');
      expect(myFitSuffix('Bank.'), 'bank');
    });

    test('says form when nothing usable is left, or it would look like a format change', () {
      expect(myFitSuffix('???'), 'form');
      expect(myFitSuffix('Converted'), 'form');
    });
  });

  group('as a slice', () {
    test('is Make it fit, for pictures, writing a JPG', () {
      final action = _college.action;
      expect(action.id, _college.id);
      expect(action.label, 'College form');
      expect(action.isFit, isTrue);
      expect(action.isFormatChange, isFalse);
      expect(action.mode, ActionMode.convert);
      expect(action.outputFor(FileKind.png), FileKind.jpg);
      expect(action.maxBytes, 50000);
      expect(keepsPhotoDetails(action), isFalse);
    });

    test('named Converted, is still Make it fit', () {
      const fit = MyFit(id: 'my-fit-c', name: 'Converted', form: FormTarget());
      expect(fit.action.isFit, isTrue);
    });

    test('two made from the same slice are equal, so menus keep their place', () {
      expect(_college.action, _college.action);
      expect(_college.action.hashCode, _college.action.hashCode);
      expect(_college.copyWith(name: 'Other').action, isNot(_college.action));
    });

    test('shows only for pictures on the Shift menu', () {
      final fits = [_college];
      expect(myFitsFor([FileKind.jpg, FileKind.heic], ActionMode.convert, fits), [_college.action]);
      expect(myFitsFor([FileKind.jpg], ActionMode.tools, fits), isEmpty);
      expect(myFitsFor([FileKind.jpg, FileKind.pdf], ActionMode.convert, fits), isEmpty);
      expect(myFitsFor(const [], ActionMode.convert, fits), isEmpty);
    });

    test('fills Form photo boxes as a preset', () {
      final preset = _college.asPreset;
      expect(preset.label('hi'), 'College form');
      expect(preset.output.width, 200);
      expect(preset.output.maxBytes, 50000);
      expect(preset.acceptsKind(FileKind.webp), isTrue);
    });
  });

  group('running', () {
    test('catalogue actions go to the engines as they are', () {
      final compress = actionById('image-compress')!;
      const options = ActionOptions(compress: CompressLevel.small);
      final run = runsAs(compress, options);
      expect(run.action, same(compress));
      expect(run.options, same(options));
    });

    test('a slice runs as Form photo with its sizes', () {
      final run = runsAs(_college.action, const ActionOptions());
      expect(run.action.id, 'image-form');
      expect(run.options.form!.width, 200);
      expect(run.options.form!.maxBytes, 50000);
      expect(run.options.nameSuffix, 'college form');
      // Over a browser's worker too.
      final back = ActionOptions.fromWire(run.options.toWire());
      expect(back.nameSuffix, 'college form');
      expect(back.form!.minBytes, 20480);
    });

    test('makes the JPG the form wants, named after the slice', () async {
      final run = runsAs(_college.action, const ActionOptions());
      final out = (await runPortable(run.action, [
        PortableFile('photo.jpg', _photo()),
      ], options: run.options)).single;
      expect(out.name, 'photo (college form).jpg');
      expect(detectKind(out.bytes), FileKind.jpg);
      final picture = img.decodeJpg(out.bytes)!;
      expect([picture.width, picture.height], [200, 230]);
      expect(out.bytes.length, inInclusiveRange(20480, 50000));
    });
  });
}
