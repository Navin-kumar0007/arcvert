import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:radial_core/radial_core.dart';

import 'preview.dart';
import 'theme.dart';

/// What Rotate, Flip or Resize would do to a picture, so the menu's centre can show it at once,
/// without converting anything.
@immutable
class LiveLook {
  const LiveLook({
    this.quarterTurns = 0,
    this.mirror = false,
    this.upsideDown = false,
    this.longSide,
  }) : half = false;

  const LiveLook.half()
    : quarterTurns = 0,
      mirror = false,
      upsideDown = false,
      longSide = null,
      half = true;

  /// Clockwise.
  final int quarterTurns;
  final bool mirror;
  final bool upsideDown;

  /// Resize's longest side, or [half] for half the size. Nothing is ever made larger.
  final int? longSide;
  final bool half;

  bool get resizes => half || longSide != null;

  /// The picture's size after this, from its size before. Null if that isn't known.
  (int, int)? sizeFrom(int? width, int? height) {
    if (width == null || height == null || !resizes) return null;
    final longest = math.max(width, height);
    final target = half ? (longest / 2).ceil() : math.min(longSide!, longest);
    final scale = target / longest;
    return ((width * scale).round(), (height * scale).round());
  }

  @override
  bool operator ==(Object other) =>
      other is LiveLook &&
      other.quarterTurns == quarterTurns &&
      other.mirror == mirror &&
      other.upsideDown == upsideDown &&
      other.longSide == longSide &&
      other.half == half;

  @override
  int get hashCode => Object.hash(quarterTurns, mirror, upsideDown, longSide, half);
}

/// The look [action] gives a picture with [options], or null for actions that change more than
/// how it's turned or sized.
LiveLook? liveLookFor(RadialAction action, ActionOptions options) {
  return switch (action.id) {
    'image-rotate' => LiveLook(quarterTurns: ((options.degrees ?? 90) ~/ 90) % 4),
    'image-flip' =>
      options.flipVertical ? const LiveLook(upsideDown: true) : const LiveLook(mirror: true),
    'image-resize' =>
      options.longSide == null ? const LiveLook.half() : LiveLook(longSide: options.longSide),
    _ => null,
  };
}

/// The file's preview picture with [look] applied: turned, flipped, or drawn smaller with its new
/// size in pixels underneath.
class LiveLookView extends StatelessWidget {
  const LiveLookView({super.key, required this.preview, required this.look, required this.size});

  final Future<Preview> preview;
  final LiveLook look;

  /// The square it's drawn in.
  final double size;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    final instant = MediaQuery.disableAnimationsOf(context);
    return FutureBuilder<Preview>(
      future: preview,
      builder: (context, made) {
        final shown = made.data;
        final picture = shown?.picture;
        if (picture == null) return const SizedBox.shrink();
        final facts = shown!.facts;
        final after = look.sizeFrom(facts.width, facts.height);
        final longest = math.max(facts.width ?? 1, facts.height ?? 1);
        // Drawn in proportion, but never so small it can't be seen.
        final shrink = after == null ? 1.0 : math.max(0.4, math.max(after.$1, after.$2) / longest);
        Widget image = Image.memory(picture, fit: BoxFit.contain, gaplessPlayback: true);
        image = Transform.flip(flipX: look.mirror, flipY: look.upsideDown, child: image);
        image = RotatedBox(quarterTurns: look.quarterTurns, child: image);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: instant ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: size * shrink,
              height: size * shrink,
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
            ),
            if (after != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${after.$1} × ${after.$2}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sd.text2),
                ),
              ),
          ],
        );
      },
    );
  }
}
