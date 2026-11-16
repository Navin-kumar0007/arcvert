import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'action_options.dart';
import 'actions.dart';
import 'detect.dart';
import 'file_kind.dart';
import 'naming.dart';
import 'pdf_writer.dart';
import 'portable_archive.dart';
import 'size_target.dart';
import 'subtitles.dart';
import 'failures.dart';

/// A file in memory.
class PortableFile {
  const PortableFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Refuses pictures larger than this, so one file cannot use up all the memory. Phones now
/// take 200 megapixel photos, and those must open.
const maxPortablePixels = 210 * 1000 * 1000;

const _readable = {
  FileKind.jpg,
  FileKind.png,
  FileKind.webp,
  FileKind.gif,
  FileKind.bmp,
  FileKind.tiff,
  FileKind.ico,
};

const _writable = {
  FileKind.jpg,
  FileKind.png,
  FileKind.webp,
  FileKind.gif,
  FileKind.tiff,
  FileKind.ico,
  FileKind.pdf,
};

/// True if [action] can run on [kind] with pure Dart: on every platform, with no engines
/// installed. Video, audio, PDF tools, archives, HEIC and AVIF need native engines.
bool canRunPortably(RadialAction action, FileKind kind) {
  if (!action.accepts.contains(kind)) return false;
  if (kind.family == FileFamily.subtitle) return true;
  if (kind.family == FileFamily.archive) return canRunArchive(action, kind);
  return _readable.contains(kind) && _writable.contains(action.outputFor(kind));
}

/// True if [action] can run on [kind] once the platform has decoded it to a PNG. Each platform reads
/// HEIC its own way, and this engine takes it from there.
bool canRunDecoded(RadialAction action, FileKind kind) {
  return kind == FileKind.heic &&
      action.accepts.contains(kind) &&
      _writable.contains(action.outputFor(kind));
}

/// What [file] becomes. A decoded HEIC photo still has its own name, and becomes what a HEIC photo
/// should rather than what its PNG would: compressing one must not make a huge PNG.
FileKind _outputKind(RadialAction action, PortableFile file, FileKind kind) {
  final name = file.name.toLowerCase();
  final decoded = name.endsWith('.heic') || name.endsWith('.heif');
  return action.outputFor(decoded ? FileKind.heic : kind);
}

/// Runs [action] on [files] and returns the results in memory. Only reads its inputs.
///
/// [onProgress] gets 0 to 1. The work yields between steps, so a page can repaint in a
/// browser, where this runs on the main thread.
Future<List<PortableFile>> runPortable(
  RadialAction action,
  List<PortableFile> files, {
  ActionOptions options = const ActionOptions(),
  void Function(double progress)? onProgress,
}) async {
  if (files.length < action.minFiles) {
    throw Fail.needsFiles(action.label, action.minFiles);
  }
  final kinds = [for (final file in files) detectKind(_head(file.bytes), fileName: file.name)];
  for (var i = 0; i < files.length; i++) {
    if (!canRunPortably(action, kinds[i])) {
      throw Fail.cantUse(action.label, files[i].name);
    }
  }

  if (action.id == 'images-scan-pdf') {
    final target = options.targetMb;
    final limit = target == null ? action.maxBytes! : (target * 1000 * 1000).round();
    final bytes = await _scanToPdf(files, limit, onProgress);
    return [PortableFile(_outputName(action, files.first.name, FileKind.pdf), bytes)];
  }
  if (combinesFiles(action)) {
    final bytes = await _imagesToPdf(files, onProgress);
    return [PortableFile(_outputName(action, files.first.name, FileKind.pdf), bytes)];
  }

  final outputs = <PortableFile>[];
  for (var i = 0; i < files.length; i++) {
    void step(double progress) => onProgress?.call((i + progress) / files.length);
    if (kinds[i].family == FileFamily.archive) {
      outputs.addAll(
        runArchive(
          action,
          files[i],
          kinds[i],
          password: options.password,
          newPassword: options.newPassword,
          keepFolders: options.keepFolders,
        ),
      );
      step(1);
      continue;
    }
    final kind = _outputKind(action, files[i], kinds[i]);
    final bytes = kinds[i].family == FileFamily.subtitle
        ? _subtitles(action, files[i], kinds[i], options)
        : await _image(action, files[i], kind, options, step);
    outputs.add(PortableFile(_outputName(action, files[i].name, kind), bytes));
  }
  onProgress?.call(1);
  return outputs;
}

List<int> _head(Uint8List bytes) {
  return bytes.length <= detectHeadBytes ? bytes : Uint8List.sublistView(bytes, 0, detectHeadBytes);
}

/// In memory nothing exists yet to collide with; saving picks the final name.
String _outputName(RadialAction action, String input, FileKind kind) {
  return freeOutputName(
    inputName: input,
    extension: kind.extension,
    suffix: action.suffix,
    exists: (_) => false,
  );
}

// Subtitles

/// The text of a subtitle action. Shared with the desktop runner.
String convertSubtitles(String actionId, String source, FileKind kind, Duration? shift) {
  final cues = parseSubtitles(source);
  if (cues.isEmpty) throw Fail.noSubtitles;
  return switch (actionId) {
    'subtitle-to-srt' => toSrt(cues),
    'subtitle-to-vtt' => toVtt(cues),
    'subtitle-to-text' => toPlainText(cues),
    _ when shift == null => throw Fail.shiftNeeded,
    _ when kind == FileKind.vtt => toVtt(shiftCues(cues, shift)),
    _ => toSrt(shiftCues(cues, shift)),
  };
}

Uint8List _subtitles(RadialAction action, PortableFile file, FileKind kind, ActionOptions options) {
  final source = utf8.decode(file.bytes, allowMalformed: true);
  return utf8.encode(convertSubtitles(action.id, source, kind, options.shift));
}

// Images

Future<void> _yield() => Future<void>.delayed(Duration.zero);

/// Decodes the first frame, upright and with all metadata gone except the colour profile:
/// EXIF holds GPS, so it never reaches an output.
img.Image _decode(
  PortableFile file, {
  required bool keepsAnimationFormat,
  bool keepsDetails = false,
}) {
  final unreadable = Fail.notAPicture(file.name);
  final decoder = img.findDecoderForData(file.bytes);
  if (decoder == null) throw unreadable;
  final img.DecodeInfo? info;
  try {
    info = decoder.startDecode(file.bytes);
  } catch (_) {
    throw unreadable;
  }
  if (info == null) throw unreadable;
  if (info.width * info.height > maxPortablePixels) {
    throw Fail.tooLargeHere(file.name);
  }
  if (keepsAnimationFormat && info.numFrames > 1) {
    throw Fail.animated(file.name);
  }

  final img.Image? decoded;
  try {
    decoded = img.decodeImage(file.bytes, frame: 0);
  } catch (_) {
    // A very large picture usually fails because the device ran out of memory.
    if (info.width * info.height > 50 * 1000 * 1000) {
      throw Fail.tooLargeForDevice(file.name);
    }
    throw unreadable;
  }
  if (decoded == null) throw unreadable;

  final upright = img.bakeOrientation(decoded);
  final plain = upright.format == img.Format.uint8 && !upright.hasPalette
      ? upright
      : upright.convert(
          format: img.Format.uint8,
          numChannels: upright.hasAlpha ? 4 : 3,
          noAnimation: true,
        );
  return plain
    ..exif = keepsDetails ? safePhotoDetails(decoded.exif) : img.ExifData()
    ..textData = null;
}

/// The photo details worth keeping, and nothing that says where it was or who has it: when it was
/// taken, with what camera and lens, and how it was exposed. Location, serial numbers, the owner's
/// name, maker notes, comments and the embedded thumbnail are left behind, and so is the turn, as
/// the picture is already upright.
img.ExifData safePhotoDetails(img.ExifData from) {
  final to = img.ExifData();
  void copy(img.IfdDirectory source, img.IfdDirectory target, List<int> tags) {
    for (final tag in tags) {
      final value = source[tag];
      if (value != null) target[tag] = value;
    }
  }

  copy(from.imageIfd, to.imageIfd, const [
    0x010F, // Make
    0x0110, // Model
    0x0132, // DateTime
    0x8298, // Copyright
  ]);
  copy(from.exifIfd, to.exifIfd, const [
    0x9003, // DateTimeOriginal
    0x9004, // DateTimeDigitized
    0x9010, // OffsetTime
    0x9011, // OffsetTimeOriginal
    0x9012, // OffsetTimeDigitized
    0x829A, // ExposureTime
    0x829D, // FNumber
    0x8822, // ExposureProgram
    0x8827, // ISOSpeedRatings
    0x9204, // ExposureBiasValue
    0x9207, // MeteringMode
    0x9209, // Flash
    0x920A, // FocalLength
    0xA403, // WhiteBalance
    0xA405, // FocalLengthIn35mmFilm
    0xA433, // LensMake
    0xA434, // LensModel
  ]);
  return to;
}

/// JPEG has no transparency. Without this, transparent areas would turn black.
img.Image _onWhite(img.Image image) {
  if (!image.hasAlpha) return image;
  final page = img.Image(width: image.width, height: image.height, numChannels: 3)
    ..iccProfile = image.iccProfile;
  img.fill(page, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(page, image);
}

Uint8List _encode(img.Image image, FileKind kind, {int? quality, bool reduceColours = false}) {
  return switch (kind) {
    FileKind.jpg => img.encodeJpg(_onWhite(image), quality: quality ?? 85),
    FileKind.webp => img.encodeWebP(
      image,
      lossless: false,
      quality: quality ?? 80,
      singleFrame: true,
    ),
    FileKind.gif => img.encodeGif(image, singleFrame: true),
    FileKind.tiff => img.encodeTiff(image, singleFrame: true),
    FileKind.ico => img.encodeIco(_longSide(image, 256), singleFrame: true),
    _ => img.encodePng(reduceColours ? img.quantize(image) : image, singleFrame: true),
  };
}

/// Shrinks so the longest side is at most [side]; never enlarges.
img.Image _longSide(img.Image image, int side) {
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= side) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: side, interpolation: img.Interpolation.average)
      : img.copyResize(image, height: side, interpolation: img.Interpolation.average);
}

/// Crops the middle to the target's shape, then scales to exactly its size.
img.Image _coverExactly(img.Image image, int width, int height) {
  final target = width / height;
  var cropWidth = image.width;
  var cropHeight = image.height;
  if (image.width / image.height > target) {
    cropWidth = (image.height * target).round();
  } else {
    cropHeight = (image.width / target).round();
  }
  final cropped = img.copyCrop(
    image,
    x: (image.width - cropWidth) ~/ 2,
    y: (image.height - cropHeight) ~/ 2,
    width: cropWidth,
    height: cropHeight,
  );
  return img.copyResize(
    cropped,
    width: width,
    height: height,
    interpolation: img.Interpolation.cubic,
  );
}

Future<Uint8List> _image(
  RadialAction action,
  PortableFile file,
  FileKind output,
  ActionOptions options,
  void Function(double) step,
) async {
  if (output == FileKind.pdf) return _imagesToPdf([file], step);

  step(0.05);
  await _yield();
  final keepsAnimation = output == FileKind.gif || output == FileKind.webp;
  final image = _decode(
    file,
    keepsAnimationFormat: keepsAnimation,
    keepsDetails: keepsPhotoDetails(action),
  );
  step(0.4);
  await _yield();

  if (action.maxBytes != null) return _underSize(action, image, output, step);

  switch (action.id) {
    case 'fit-whatsapp-photo':
      return _encode(_longSide(image, 1600), output, quality: 80);
    case 'fit-web':
      return _encode(_longSide(image, 1920), output, quality: 80);
    case 'fit-instagram':
      return _encode(_coverExactly(image, 1080, 1350), output, quality: 85);
    case 'image-resize':
      final longest = image.width > image.height ? image.width : image.height;
      final side = options.longSide ?? (longest / 2).ceil();
      return _encode(_longSide(image, side), output);
    case 'image-compress':
      final compressed = _encode(
        image,
        output,
        quality: compressPictureQuality(options.compress),
        // A palette costs colours, which Best quality keeps.
        reduceColours: options.compress != CompressLevel.high,
      );
      // Saving a photo that was saved at high quality again, at Best quality, can come out larger.
      // Compress must never hand back a bigger file of the same kind. A change of kind, as a HEIC
      // photo decoded to PNG becoming a JPEG, can't be compared by size.
      final same = detectKind(_head(file.bytes), fileName: file.name) == output;
      if (same && compressed.length >= file.bytes.length) throw Fail.pictureAsSmall;
      return compressed;
    case 'image-rotate':
      final degrees = options.degrees ?? 90;
      if (degrees != 90 && degrees != 180 && degrees != 270) {
        throw Fail.pictureRotate(degrees);
      }
      return _encode(img.copyRotate(image, angle: degrees), output);
    case 'image-flip':
      final direction = options.flipVertical
          ? img.FlipDirection.vertical
          : img.FlipDirection.horizontal;
      return _encode(img.copyFlip(image, direction: direction), output);
    case 'image-crop':
      final crop = options.crop;
      if (crop == null) throw Fail.cropNeeded;
      return _encode(_cropped(image, crop), output);
    case 'image-form':
      return _forForm(image, options, step);
  }
  return _encode(image, output);
}

img.Image _cropped(img.Image image, ({int left, int top, int width, int height}) crop) {
  final fits =
      crop.left >= 0 &&
      crop.top >= 0 &&
      crop.width > 0 &&
      crop.height > 0 &&
      crop.left + crop.width <= image.width &&
      crop.top + crop.height <= image.height;
  if (!fits) throw Fail.editDoesntFit;
  return img.copyCrop(image, x: crop.left, y: crop.top, width: crop.width, height: crop.height);
}

/// Without a pixel size a form takes any, and a phone photo has far more than one needs.
const _formLongestSide = 1200;

/// Signatures are cleaned at most this size, which keeps every stroke of a form's few hundred
/// pixels.
const _signatureWorkingSide = 1600;

/// A signature photographed or scanned on paper, made ready for a form: cropped to the ink with a
/// small margin, the paper made white and the ink darker. The ink keeps its own colour, so a blue
/// signature stays blue. Throws [Fail.noSignature] if no ink stands out from the paper.
img.Image cleanSignature(img.Image source) {
  final width = source.width;
  final height = source.height;
  final light = Uint8List(width * height);
  final counts = List<int>.filled(256, 0);
  final red = Uint8List(width * height);
  final green = Uint8List(width * height);
  final blue = Uint8List(width * height);
  var i = 0;
  for (final pixel in source) {
    // Clear parts count as paper.
    final alpha = pixel.aNormalized.toDouble();
    int onWhite(num value, num max) =>
        (value / max * 255 * alpha + 255 * (1 - alpha)).round().clamp(0, 255);
    final max = pixel.maxChannelValue;
    final r = onWhite(pixel.r, max), g = onWhite(pixel.g, max), b = onWhite(pixel.b, max);
    red[i] = r;
    green[i] = g;
    blue[i] = b;
    final level = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    light[i] = level;
    counts[level]++;
    i++;
  }

  // A signature covers far less than half the picture, however tightly it's framed, so the median
  // is paper, and the spread above it says how uneven the paper is. The darkest few pixels are
  // ink, if there is any. A share-based split such as Otsu's fails when ink is a tiny share.
  final total = width * height;
  final median = _levelAt(counts, total, 0.5);
  final paper = _levelAt(counts, total, 0.75);
  final paperEdge = median - 3 * (paper - median) - 6;
  final ink = _levelAt(counts, total, 0.0005);
  final threshold = (ink + paperEdge) ~/ 2;
  var inked = 0;
  for (var level = 0; level <= threshold && level < 256; level++) {
    inked += counts[level];
  }
  // No ink much darker than the paper is a blank page or a photo of a wall.
  if (paperEdge - ink < 40 || inked < total * 0.0003) throw Fail.noSignature;

  // Where the ink is, ignoring single stray dots of dust: an inked pixel counts only beside another.
  bool inkAt(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && light[y * width + x] <= threshold;
  var top = height, bottom = -1, left = width, right = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!inkAt(x, y)) continue;
      final joined =
          inkAt(x - 1, y) ||
          inkAt(x + 1, y) ||
          inkAt(x, y - 1) ||
          inkAt(x, y + 1) ||
          inkAt(x - 1, y - 1) ||
          inkAt(x + 1, y + 1) ||
          inkAt(x - 1, y + 1) ||
          inkAt(x + 1, y - 1);
      if (!joined) continue;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  if (right < 0) throw Fail.noSignature;
  final margin = ((right - left).clamp(bottom - top, width) * 0.06).round().clamp(4, 200);
  final x0 = (left - margin).clamp(0, width - 1);
  final y0 = (top - margin).clamp(0, height - 1);
  final x1 = (right + margin).clamp(0, width - 1);
  final y1 = (bottom + margin).clamp(0, height - 1);

  final out = img.Image(width: x1 - x0 + 1, height: y1 - y0 + 1);
  final span = (paper - ink).toDouble();
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final at = y * width + x;
      // 0 is the darkest ink, 1 the paper; anything near the paper becomes paper.
      var whiteness = ((light[at] - ink) / span).clamp(0.0, 1.0);
      whiteness = whiteness >= 0.8 ? 1.0 : whiteness / 0.8;
      final cover = 1 - whiteness;
      int mix(int channel) => (255 * whiteness + channel * 0.55 * cover).round().clamp(0, 255);
      out.setPixelRgb(x - x0, y - y0, mix(red[at]), mix(green[at]), mix(blue[at]));
    }
  }
  return out;
}

/// The level below which [share] of the pixels fall.
int _levelAt(List<int> counts, int total, double share) {
  final wanted = total * share;
  var seen = 0;
  for (var level = 0; level < 256; level++) {
    seen += counts[level];
    if (seen >= wanted) return level;
  }
  return 255;
}

/// Strokes thinned by shrinking come back darker: each channel is curved towards black, so white
/// stays white and the ink keeps its colour.
img.Image _deepenInk(img.Image image) {
  for (final pixel in image) {
    int deepen(num value) => (255 * (value / 255) * (value / 255)).round();
    pixel
      ..r = deepen(pixel.r)
      ..g = deepen(pixel.g)
      ..b = deepen(pixel.b);
  }
  return image;
}

/// [image] made as large as fits in [width] by [height], in the middle of white. Nothing is cut,
/// which matters for a signature, unlike a photo that a form expects filled.
img.Image _containOnWhite(img.Image image, int width, int height) {
  final scale = width / image.width < height / image.height
      ? width / image.width
      : height / image.height;
  final fitted = img.copyResize(
    image,
    width: (image.width * scale).round().clamp(1, width),
    height: (image.height * scale).round().clamp(1, height),
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(
    canvas,
    fitted,
    dstX: (width - fitted.width) ~/ 2,
    dstY: (height - fitted.height) ~/ 2,
  );
}

/// A JPEG the size a form asks for. It only crops and scales: forms may reject retouched photos.
Future<Uint8List> _forForm(
  img.Image source,
  ActionOptions options,
  void Function(double) step,
) async {
  final form = options.form;
  if (form == null) throw Fail.formNeeded;
  final width = form.width;
  final height = form.height;
  if ((width == null) != (height == null)) {
    throw Fail.widthAndHeight;
  }
  final minBytes = form.minBytes ?? 0;
  final maxBytes = form.maxBytes;
  if (maxBytes != null && minBytes > maxBytes) {
    throw Fail.smallestOverLargest;
  }

  final crop = options.crop;
  var framed = crop == null ? source : _cropped(source, crop);
  if (form.signature) {
    // A phone photo of a page is far bigger than a signature needs, and this goes pixel by pixel.
    framed = cleanSignature(_longSide(framed, _signatureWorkingSide));
    await _yield();
  }
  final exact = width != null && height != null;
  final image = !exact
      ? _longSide(framed, _formLongestSide)
      : form.signature
      ? _deepenInk(_containOnWhite(framed, width, height))
      : _coverExactly(framed, width, height);
  await _yield();

  final Uint8List best;
  if (maxBytes == null) {
    best = _encode(image, FileKind.jpg, quality: 90);
  } else if (exact) {
    best = await _highestQualityUnder(image, maxBytes, step);
  } else {
    best = await _underBytes(image, FileKind.jpg, maxBytes, Fail.pictureTooBigForForm, step);
  }
  return _paddedTo(best, minBytes);
}

/// The sharpest JPEG under [maxBytes], keeping the picture's size, since the form set it.
Future<Uint8List> _highestQualityUnder(
  img.Image image,
  int maxBytes,
  void Function(double) step,
) async {
  var low = 10;
  var high = 100;
  Uint8List? fitting;
  var tries = 0;
  while (low <= high) {
    await _yield();
    tries++;
    step(0.4 + 0.55 * (1 - 1 / (tries + 1)));
    final quality = (low + high) ~/ 2;
    final bytes = _encode(image, FileKind.jpg, quality: quality);
    if (bytes.length <= maxBytes) {
      fitting = bytes;
      low = quality + 1;
    } else {
      high = quality - 1;
    }
  }
  if (fitting == null) {
    throw Fail.tooMuchDetail(maxBytes ~/ 1000, image.width, image.height);
  }
  return fitting;
}

/// Forms refuse files that are too small, and a plain signature can be small at any quality. A
/// JPEG may carry comments that nothing draws, so empty ones bring it up to [minBytes].
Uint8List _paddedTo(Uint8List jpeg, int minBytes) {
  var missing = minBytes - jpeg.length;
  if (missing <= 0) return jpeg;
  // Comments go after the JFIF header, which some readers insist comes first.
  var at = 2;
  if (jpeg.length > 5 && jpeg[2] == 0xFF && jpeg[3] == 0xE0) {
    at = 4 + (jpeg[4] << 8 | jpeg[5]);
  }
  final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(jpeg, 0, at));
  while (missing > 0) {
    // A segment's length counts itself, and it costs two more bytes for its marker.
    const most = 65535;
    final total = (missing + 2).clamp(4, most + 2);
    final length = total - 2;
    out
      ..add([0xFF, 0xFE, length >> 8, length & 0xFF])
      ..add(Uint8List(length - 2));
    missing -= total;
  }
  out.add(Uint8List.sublistView(jpeg, at));
  return out.takeBytes();
}

Future<Uint8List> _underSize(
  RadialAction action,
  img.Image image,
  FileKind output,
  void Function(double) step,
) {
  return _underBytes(image, output, action.maxBytes!, Fail.pictureTooBig(action.label), step);
}

Future<Uint8List> _underBytes(
  img.Image image,
  FileKind output,
  int maxBytes,
  EngineFailed tooBig,
  void Function(double) step,
) async {
  final hasQuality = output == FileKind.jpg || output == FileKind.webp;
  final longest = image.width > image.height ? image.width : image.height;
  Uint8List? fitting;
  var tries = 0;

  final best = await searchUnderSize(
    maxBytes: maxBytes,
    // Without a quality setting, only shrinking changes the size.
    minQuality: hasQuality ? 40 : 85,
    maxQuality: hasQuality ? 95 : 85,
    encode: (quality, scale) async {
      await _yield();
      tries++;
      step(0.4 + 0.55 * (1 - 1 / (tries + 1)));
      final side = (longest * scale).round().clamp(1, longest);
      final bytes = _encode(_longSide(image, side), output, quality: quality);
      // The search only moves on to better settings after a fit, so the last fit is the best.
      if (bytes.length <= maxBytes) fitting = bytes;
      return bytes.length;
    },
  );
  final result = fitting;
  if (best == null || result == null) {
    throw tooBig;
  }
  return result;
}

/// A scanned page's longer side: A4 at 150 dots an inch, enough to read and print text.
const _scanPageSide = 1754;

/// Photos of pages made into one greyscale PDF under [maxBytes], each page cleaned as a scanner app
/// would: paper white, text black. Pages print at A4 size.
Future<Uint8List> _scanToPdf(
  List<PortableFile> files,
  int maxBytes,
  void Function(double)? onProgress,
) async {
  final pages = <img.Image>[];
  for (var i = 0; i < files.length; i++) {
    await _yield();
    final photo = _decode(files[i], keepsAnimationFormat: false);
    pages.add(cleanPage(_longSide(photo, _scanPageSide)));
    onProgress?.call(0.4 * (i + 1) / files.length);
  }
  Uint8List? fitting;
  var tries = 0;
  final best = await searchUnderSize(
    maxBytes: maxBytes,
    minQuality: 30,
    maxQuality: 85,
    // Below about half of 150 dots an inch, small print can't be read.
    minScale: 0.45,
    encode: (quality, scale) async {
      await _yield();
      tries++;
      onProgress?.call(0.4 + 0.55 * (1 - 1 / (tries + 1)));
      final jpegs = [
        for (final page in pages)
          _encode(
            _longSide(
              page,
              ((page.width > page.height ? page.width : page.height) * scale).round(),
            ),
            FileKind.jpg,
            quality: quality,
          ),
      ];
      final pdf = buildImagePdf(jpegs, pageLongSide: 842);
      if (pdf.length <= maxBytes) fitting = pdf;
      return pdf.length;
    },
  );
  final result = fitting;
  if (best == null || result == null) throw Fail.scanTooBig(maxBytes ~/ 1000);
  onProgress?.call(1);
  return result;
}

/// A photo of a page, greyscale, with its paper made white and its print black, so it reads like
/// a scan and compresses well. Most of a page is paper, so its brighter quarter sets white.
img.Image cleanPage(img.Image photo) {
  final counts = List<int>.filled(256, 0);
  final levels = Uint8List(photo.width * photo.height);
  var i = 0;
  for (final pixel in photo) {
    final max = pixel.maxChannelValue;
    final level = ((0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / max * 255).round().clamp(
      0,
      255,
    );
    levels[i++] = level;
    counts[level]++;
  }
  final total = photo.width * photo.height;
  final paper = _levelAt(counts, total, 0.75);
  final ink = _levelAt(counts, total, 0.01);
  final span = (paper - ink).clamp(1, 255).toDouble();
  final page = img.Image(width: photo.width, height: photo.height);
  i = 0;
  for (final pixel in page) {
    var whiteness = ((levels[i++] - ink) / span).clamp(0.0, 1.0);
    whiteness = whiteness >= 0.85 ? 1.0 : whiteness / 0.85;
    final grey = (255 * whiteness * whiteness).round();
    pixel
      ..r = grey
      ..g = grey
      ..b = grey;
  }
  return page;
}

Future<Uint8List> _imagesToPdf(List<PortableFile> files, void Function(double)? onProgress) async {
  final pages = <Uint8List>[];
  for (var i = 0; i < files.length; i++) {
    await _yield();
    pages.add(_encode(_decode(files[i], keepsAnimationFormat: false), FileKind.jpg, quality: 90));
    onProgress?.call((i + 1) / files.length);
  }
  return buildImagePdf(pages);
}
