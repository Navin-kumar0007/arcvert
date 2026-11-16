import 'action_options.dart';
import 'actions.dart';

/// One of an action's choices, shown on the menu's outer ring around its slice.
class RingChoice {
  const RingChoice(this.key, this.label, this.options);

  /// Names the choice so the app can translate it. Pixel sizes share `resizePixels`, as "1280 px"
  /// reads the same in every language.
  final String key;

  /// In English, as action labels in `core` are.
  final String label;
  final ActionOptions options;
}

/// Longest sides offered for Resize, besides half. Nothing is ever made larger.
const ringLongSides = [1920, 1280, 640];

const _rotations = [
  RingChoice('rotateRight', '90° right', ActionOptions(degrees: 90)),
  RingChoice('rotateAround', '180°', ActionOptions(degrees: 180)),
  RingChoice('rotateLeft', '90° left', ActionOptions(degrees: 270)),
];

const _flips = [
  RingChoice('flipSideways', 'Mirror', ActionOptions()),
  RingChoice('flipUpsideDown', 'Upside down', ActionOptions(flipVertical: true)),
];

final _resizes = [
  const RingChoice('resizeHalf', 'Half', ActionOptions()),
  for (final side in ringLongSides)
    RingChoice('resizePixels', '$side px', ActionOptions(longSide: side)),
];

/// Compress's levels. The first is what Compress always did.
const _compressLevels = [
  RingChoice('compressBalanced', 'Balanced', ActionOptions()),
  RingChoice('compressBest', 'Best quality', ActionOptions(compress: CompressLevel.high)),
  RingChoice('compressSmallest', 'Smallest', ActionOptions(compress: CompressLevel.small)),
];

/// Size limits for Scanned document. The first is the slice's own.
const _scanLimits = [
  RingChoice('scanUnder', 'Under 1 MB', ActionOptions()),
  RingChoice('scanUnder', 'Under 500 KB', ActionOptions(targetMb: 0.5)),
  RingChoice('scanUnder', 'Under 200 KB', ActionOptions(targetMb: 0.2)),
];

/// The choices [action] offers on the outer ring, or none. The first is what choosing the slice
/// itself does, so the ring only adds ways to run it, using options every engine already honours.
List<RingChoice> ringChoices(RadialAction action) {
  return switch (action.id) {
    'image-rotate' || 'video-rotate' || 'pdf-rotate' => _rotations,
    'image-flip' => _flips,
    'image-resize' || 'video-resize' => _resizes,
    'images-scan-pdf' => _scanLimits,
    'image-compress' || 'video-compress' || 'pdf-compress' => _compressLevels,
    _ => const [],
  };
}
