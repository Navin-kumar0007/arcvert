import 'package:flutter_test/flutter_test.dart';
import 'package:radial_core/radial_core.dart';
import 'package:arcvert/live_look.dart';

void main() {
  RadialAction action(String id) => actionById(id)!;

  test('Rotate turns by its degrees, a quarter turn by default', () {
    expect(liveLookFor(action('image-rotate'), const ActionOptions())!.quarterTurns, 1);
    expect(liveLookFor(action('image-rotate'), const ActionOptions(degrees: 180))!.quarterTurns, 2);
    expect(liveLookFor(action('image-rotate'), const ActionOptions(degrees: 270))!.quarterTurns, 3);
  });

  test('Flip mirrors, or turns upside down', () {
    expect(liveLookFor(action('image-flip'), const ActionOptions()), const LiveLook(mirror: true));
    expect(
      liveLookFor(action('image-flip'), const ActionOptions(flipVertical: true)),
      const LiveLook(upsideDown: true),
    );
  });

  test('Resize says the size it makes, and never makes a picture larger', () {
    final half = liveLookFor(action('image-resize'), const ActionOptions())!;
    expect(half.sizeFrom(4032, 3024), (2016, 1512));
    final to1280 = liveLookFor(action('image-resize'), const ActionOptions(longSide: 1280))!;
    expect(to1280.sizeFrom(4032, 3024), (1280, 960));
    expect(to1280.sizeFrom(800, 600), (800, 600));
    expect(to1280.sizeFrom(null, 600), isNull);
  });

  test('anything that changes more than the turn or size has no look', () {
    for (final id in [
      'image-compress',
      'image-to-png',
      'image-crop',
      'pdf-rotate',
      'video-rotate',
    ]) {
      expect(liveLookFor(action(id), const ActionOptions()), isNull, reason: id);
    }
  });
}
