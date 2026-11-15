import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:radial_core/radial_core.dart';

import 'action_icons.dart';
import 'size_preview.dart';
import 'theme.dart';
import 'words.dart';

/// The dial on a phone: half of it, along the bottom where a thumb reaches, with a big button to
/// run what is chosen. Tapping a slice chooses it and says how big the result will be; its choices,
/// such as Rotate's 180°, sit above as chips. Takes what [RadialMenu] takes.
class ThumbArc extends StatefulWidget {
  const ThumbArc({
    super.key,
    required this.actions,
    required this.onSelected,
    required this.onCancelled,
    this.onChoice,
    this.sizeOf,
    this.fileCount = 1,
    this.perPage = 5,
  });

  final List<RadialAction> actions;
  final ValueChanged<RadialAction> onSelected;
  final VoidCallback onCancelled;
  final void Function(RadialAction action, ActionOptions options)? onChoice;
  final SizeGuesser? sizeOf;
  final int fileCount;

  /// Slices on the arc at once, "More" included when there are more.
  final int perPage;

  @override
  State<ThumbArc> createState() => _ThumbArcState();
}

class _ThumbArcState extends State<ThumbArc> {
  int _page = 0;
  int _chosen = 0;
  int _choice = 0;
  final _sizes = <String, SizeGuess?>{};

  List<List<RadialAction>> get _pages {
    final actions = widget.actions;
    if (actions.length <= widget.perPage) return [actions];
    final room = widget.perPage - 1;
    return [
      for (var start = 0; start < actions.length; start += room)
        actions.sublist(start, math.min(start + room, actions.length)),
    ];
  }

  bool get _hasMore => _pages.length > 1;
  List<RadialAction> get _shown => widget.actions.isEmpty ? const [] : _pages[_page];
  int get _sliceCount => _shown.length + (_hasMore ? 1 : 0);
  bool _isMore(int slice) => _hasMore && slice == _shown.length;
  RadialAction? get _action => _chosen < _shown.length ? _shown[_chosen] : null;

  @override
  void initState() {
    super.initState();
    _askSize();
  }

  @override
  void didUpdateWidget(ThumbArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions != widget.actions) {
      _page = 0;
      _chosen = 0;
      _choice = 0;
      _askSize();
    }
  }

  void _askSize() {
    final sizeOf = widget.sizeOf;
    final action = _action;
    if (sizeOf == null || action == null || _sizes.containsKey(action.id)) return;
    _sizes[action.id] = null;
    unawaited(() async {
      SizeGuess? guess;
      try {
        guess = await sizeOf(action);
      } catch (_) {
        // Without a size the arc works as before.
      }
      if (mounted) setState(() => _sizes[action.id] = guess);
    }());
  }

  void _tapSlice(int slice) {
    if (_isMore(slice)) {
      setState(() {
        _page = (_page + 1) % _pages.length;
        _chosen = 0;
        _choice = 0;
      });
    } else {
      setState(() {
        _chosen = slice;
        _choice = 0;
      });
    }
    _askSize();
  }

  void _run() {
    final action = _action;
    if (action == null) return;
    final onChoice = widget.onChoice;
    if (_choice == 0 || onChoice == null) {
      widget.onSelected(action);
    } else {
      onChoice(action, ringChoices(action)[_choice].options);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    final action = _action;
    final fit = action?.isFit ?? false;
    final hi = fit ? sd.amber : sd.accent;
    final hiInk = fit ? sd.amberInk : sd.accentInk;
    final choices = action == null || widget.onChoice == null
        ? const <RingChoice>[]
        : ringChoices(action);
    final size = action == null || _choice != 0 ? null : _sizes[action.id];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SdPanel(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action == null ? words.nothingFits : actionLabel(words, action.label),
                        style: TextStyle(fontSize: 13, color: sd.muted),
                      ),
                      Text(
                        size?.describe(words) ?? ' ',
                        style: const TextStyle(
                          fontFamily: headingFont,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onCancelled,
                child: Text(
                  widget.fileCount > 1 ? words.cancelFiles(widget.fileCount) : words.cancel,
                ),
              ),
            ],
          ),
        ),
        if (choices.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < choices.length; i++)
                ChoiceChip(
                  label: Text(ringChoiceLabel(words, choices[i])),
                  selected: i == _choice,
                  showCheckmark: false,
                  selectedColor: hi,
                  labelStyle: TextStyle(
                    color: i == _choice ? hiInk : sd.text,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _choice = i),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 420.0);
            return _buildArc(context, width, hi, hiInk, action);
          },
        ),
      ],
    );
  }

  Widget _buildArc(
    BuildContext context,
    double width,
    Color hi,
    Color hiInk,
    RadialAction? action,
  ) {
    final words = context.words;
    final sd = context.sd;
    final radius = width / 2;
    final inner = radius * 0.42;
    final count = _sliceCount;
    final span = count == 0 ? 0.0 : math.pi / count;
    final labelRadius = (radius + inner) / 2;
    final height = radius + 8;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _ArcPainter(
                  count: count,
                  chosen: _chosen,
                  fits: [for (var i = 0; i < count; i++) !_isMore(i) && _shown[i].isFit],
                  radius: radius,
                  inner: inner,
                  fill: sd.surface,
                  fitFill: sd.amberSoft,
                  line: sd.line2,
                  hi: hi,
                ),
              ),
            ),
          ),
          for (var i = 0; i < count; i++)
            _slice(context, i, radius, labelRadius, span, height, hiInk),
          Positioned(
            left: radius - inner + 6,
            top: height - inner + 6,
            width: (inner - 6) * 2,
            height: inner - 6,
            child: Material(
              color: sd.text,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: action == null ? null : _run,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action == null ? words.cancel : actionLabel(words, action.label),
                        style: TextStyle(color: sd.bg, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slice(
    BuildContext context,
    int i,
    double radius,
    double labelRadius,
    double span,
    double height,
    Color hiInk,
  ) {
    final words = context.words;
    final sd = context.sd;
    final more = _isMore(i);
    final action = more ? null : _shown[i];
    final on = i == _chosen && !more;
    final angle = math.pi + span * (i + 0.5);
    final centre = Offset(
      radius + labelRadius * math.cos(angle),
      height + labelRadius * math.sin(angle),
    );
    final label = more ? words.more : actionLabel(words, action!.label);
    final colour = on ? hiInk : ((action?.isFit ?? false) ? sd.amberText : sd.text);
    return Positioned(
      left: centre.dx - 40,
      top: centre.dy - 30,
      width: 80,
      height: 60,
      child: Semantics(
        button: true,
        selected: on,
        label: more ? words.moreActions : label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapSlice(i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(more ? Icons.more_horiz : iconFor(action!), size: 20, color: colour),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  color: colour,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.count,
    required this.chosen,
    required this.fits,
    required this.radius,
    required this.inner,
    required this.fill,
    required this.fitFill,
    required this.line,
    required this.hi,
  });

  final int count;
  final int chosen;
  final List<bool> fits;
  final double radius;
  final double inner;
  final Color fill;
  final Color fitFill;
  final Color line;
  final Color hi;

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final centre = Offset(radius, size.height);
    final outer = Rect.fromCircle(center: centre, radius: radius);
    final hole = Rect.fromCircle(center: centre, radius: inner);
    final span = math.pi / count;
    const gap = 0.008;
    for (var i = 0; i < count; i++) {
      final start = math.pi + i * span + gap;
      final sweep = span - 2 * gap;
      final slice = Path()
        ..arcTo(outer, start, sweep, true)
        ..arcTo(hole, start + sweep, -sweep, false)
        ..close();
      final colour = i == chosen ? hi : (fits[i] ? Color.alphaBlend(fitFill, fill) : fill);
      canvas.drawPath(slice, Paint()..color = colour);
      canvas.drawPath(
        slice,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.chosen != chosen ||
        oldDelegate.hi != hi ||
        oldDelegate.fill != fill;
  }
}
