/// What a form wants a picture to be. Pixel sizes come as a pair or not at all.
class FormTarget {
  const FormTarget({this.width, this.height, this.minBytes, this.maxBytes});

  final int? width;
  final int? height;
  final int? minBytes;
  final int? maxBytes;
}

/// Bytes that count as at least [kb] KB however a form's website counts a KB, 1000 or 1024 bytes.
int formMinBytes(int kb) => kb * 1024;

/// Bytes that count as at most [kb] KB however a form's website counts a KB, 1000 or 1024 bytes.
int formMaxBytes(int kb) => kb * 1000;

/// The KB that [formMinBytes] and [formMaxBytes] made these from, to show.
int formMinKb(int bytes) => bytes ~/ 1024;
int formMaxKb(int bytes) => bytes ~/ 1000;

/// The choices an action may need from the user.
class ActionOptions {
  const ActionOptions({
    this.longSide,
    this.crop,
    this.degrees,
    this.flipVertical = false,
    this.startSeconds,
    this.endSeconds,
    this.pages,
    this.password,
    this.newPassword,
    this.audioKbps,
    this.targetMb,
    this.shift,
    this.form,
  });

  final int? longSide;

  /// Left, top, width, height in pixels.
  final ({int left, int top, int width, int height})? crop;

  /// Clockwise: 90, 180 or 270.
  final int? degrees;
  final bool flipVertical;
  final double? startSeconds;
  final double? endSeconds;

  /// A qpdf page range such as `1-3,7`.
  final String? pages;

  /// What opens a locked file. Held only for the job, and never logged or shown.
  final String? password;

  /// What a result should be locked with.
  final String? newPassword;
  final int? audioKbps;
  final double? targetMb;
  final Duration? shift;
  final FormTarget? form;

  /// Every choice as plain values, for crossing to a browser's worker, which can only be sent
  /// maps, lists, text and numbers. [fromWire] reads it back; a test checks no choice is lost.
  Map<String, Object?> toWire() {
    final crop = this.crop;
    final form = this.form;
    return {
      'longSide': longSide,
      'crop': crop == null ? null : [crop.left, crop.top, crop.width, crop.height],
      'degrees': degrees,
      'flipVertical': flipVertical,
      'startSeconds': startSeconds,
      'endSeconds': endSeconds,
      'pages': pages,
      'password': password,
      'newPassword': newPassword,
      'audioKbps': audioKbps,
      'targetMb': targetMb,
      'shiftMs': shift?.inMilliseconds,
      'form': form == null
          ? null
          : {
              'width': form.width,
              'height': form.height,
              'minBytes': form.minBytes,
              'maxBytes': form.maxBytes,
            },
    };
  }

  /// The choices [toWire] wrote. Numbers may arrive as either kind, as a browser has only one.
  static ActionOptions fromWire(Map<Object?, Object?> wire) {
    int? whole(Object? value) => value is num ? value.toInt() : null;
    double? real(Object? value) => value is num ? value.toDouble() : null;
    final crop = wire['crop'];
    final form = wire['form'];
    return ActionOptions(
      longSide: whole(wire['longSide']),
      crop: crop is List && crop.length == 4
          ? (
              left: whole(crop[0])!,
              top: whole(crop[1])!,
              width: whole(crop[2])!,
              height: whole(crop[3])!,
            )
          : null,
      degrees: whole(wire['degrees']),
      flipVertical: wire['flipVertical'] == true,
      startSeconds: real(wire['startSeconds']),
      endSeconds: real(wire['endSeconds']),
      pages: wire['pages'] as String?,
      password: wire['password'] as String?,
      newPassword: wire['newPassword'] as String?,
      audioKbps: whole(wire['audioKbps']),
      targetMb: real(wire['targetMb']),
      shift: wire['shiftMs'] == null ? null : Duration(milliseconds: whole(wire['shiftMs'])!),
      form: form is Map
          ? FormTarget(
              width: whole(form['width']),
              height: whole(form['height']),
              minBytes: whole(form['minBytes']),
              maxBytes: whole(form['maxBytes']),
            )
          : null,
    );
  }

  /// These same choices, with what opens a locked file.
  ActionOptions withPassword(String value) {
    return ActionOptions(
      longSide: longSide,
      crop: crop,
      degrees: degrees,
      flipVertical: flipVertical,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      pages: pages,
      password: value,
      newPassword: newPassword,
      audioKbps: audioKbps,
      targetMb: targetMb,
      shift: shift,
      form: form,
    );
  }
}

/// An engine could not do the job. [message] is written for the user; [details] is what
/// the engine said, for the Copy details button. [key] and [args] say which message it is, from
/// `Fail`, so it can be translated; [message] is the English.
class EngineFailed implements Exception {
  const EngineFailed(this.message, {this.details = '', this.key, this.args = const {}});

  final String message;
  final String details;
  final String? key;
  final Map<String, String> args;

  /// The same failure, with what the engine said.
  EngineFailed withDetails(String details) =>
      EngineFailed(message, details: details, key: key, args: args);

  @override
  String toString() => details.isEmpty ? message : '$message\n$details';
}

/// A file is locked and no password given opens it, so the app can ask. A wrong password and none
/// at all look the same from here.
class PasswordNeeded extends EngineFailed {
  PasswordNeeded(this.fileName)
    : super(
        '$fileName has a password, so it wasn\'t opened.',
        key: 'passwordNeeded',
        args: {'name': fileName},
      );

  final String fileName;
}

/// Seconds from a time as people write it: `90`, `1:30`, `1:02:03` or `1:30.5`. Null if it isn't one.
double? parseClock(String text) {
  final parts = text.trim().split(':');
  if (parts.length > 3) return null;
  var seconds = 0.0;
  for (var i = 0; i < parts.length; i++) {
    final isLast = i == parts.length - 1;
    final part = parts[i];
    if (!RegExp(isLast ? r'^\d+(\.\d+)?$' : r'^\d+$').hasMatch(part)) return null;
    final value = double.parse(part);
    // Only the first part may run past 59: `90` and `90:00` are fine, `1:90` is a typo.
    if (i > 0 && value >= 60) return null;
    seconds = seconds * 60 + value;
  }
  return seconds;
}

/// A time as people write it, which [parseClock] reads back: `0:05`, `1:30.5`, `1:02:03`.
String formatClock(double seconds) {
  final tenths = (seconds.clamp(0, double.infinity) * 10).round();
  final whole = tenths ~/ 10;
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = whole >= 3600
      ? '${whole ~/ 3600}:${two(whole ~/ 60 % 60)}:${two(whole % 60)}'
      : '${whole ~/ 60}:${two(whole % 60)}';
  return tenths % 10 == 0 ? clock : '$clock.${tenths % 10}';
}
