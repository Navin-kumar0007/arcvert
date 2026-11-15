import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:radial_core/radial_core.dart';

import 'conversion.dart' show formatBytes;
import 'theme.dart';
import 'words.dart';

/// The dial before any file is in: the slices it will offer, drawn faintly, around a centre that
/// chooses files. It is where files are dropped, so it says so at a glance.
class IdleDial extends StatelessWidget {
  const IdleDial({super.key, required this.centre, this.diameter = 440});

  final Widget centre;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    final slices = <(String, bool)>[
      ('JPG', false),
      ('PNG', false),
      (words.fitChat, true),
      (words.fitEmail, true),
      (actionLabel(words, 'Under 100 KB'), true),
      (actionLabel(words, 'Compress'), false),
      (actionLabel(words, 'Resize'), false),
      ('PDF', false),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(diameter, constraints.maxWidth);
        final radius = size / 2;
        final labelRadius = radius * 0.69;
        final span = 2 * math.pi / slices.length;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _IdleDialPainter(
                      fits: [for (final slice in slices) slice.$2],
                      fill: sd.dialFill,
                      line: sd.line2,
                      fitFill: sd.amberSoft,
                      fitLine: sd.amberLine,
                      orbit: sd.accentLine,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < slices.length; i++)
                Positioned(
                  left: radius + labelRadius * math.cos(-math.pi / 2 + i * span) - 44,
                  top: radius + labelRadius * math.sin(-math.pi / 2 + i * span) - 18,
                  width: 88,
                  height: 36,
                  child: ExcludeSemantics(
                    child: Center(
                      child: Text(
                        slices[i].$1,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: slices[i].$2 ? sd.amberText : sd.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: Container(
                  width: size * 0.44,
                  height: size * 0.44,
                  decoration: BoxDecoration(
                    color: sd.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: sd.accent, width: 1.5),
                    boxShadow: sd.cardShadow,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Center(child: centre),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IdleDialPainter extends CustomPainter {
  const _IdleDialPainter({
    required this.fits,
    required this.fill,
    required this.line,
    required this.fitFill,
    required this.fitLine,
    required this.orbit,
  });

  final List<bool> fits;
  final Color fill;
  final Color line;
  final Color fitFill;
  final Color fitLine;
  final Color orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    final outer = Rect.fromCircle(center: centre, radius: radius * 0.93);
    final inner = Rect.fromCircle(center: centre, radius: radius * 0.44);
    final span = 2 * math.pi / fits.length;
    const gap = 0.012;
    for (var i = 0; i < fits.length; i++) {
      final start = -math.pi / 2 + i * span - span / 2 + gap;
      final sweep = span - 2 * gap;
      final slice = Path()
        ..arcTo(outer, start, sweep, true)
        ..arcTo(inner, start + sweep, -sweep, false)
        ..close();
      canvas.drawPath(slice, Paint()..color = fits[i] ? fitFill : fill);
      canvas.drawPath(
        slice,
        Paint()
          ..color = fits[i] ? fitLine : line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    // A dotted orbit just outside, as the edge of where a drop lands.
    final dot = Paint()..color = orbit;
    const dots = 120;
    for (var i = 0; i < dots; i++) {
      final angle = 2 * math.pi * i / dots;
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.98),
        1,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_IdleDialPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.line != line || oldDelegate.orbit != orbit;
  }
}

/// "Offline · nothing is uploaded", beside the title.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: sd.accentSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: sd.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            context.words.offlineBadge,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sd.accentText),
          ),
        ],
      ),
    );
  }
}

/// A key drawn as a key.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: sd.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          top: BorderSide(color: sd.line2),
          left: BorderSide(color: sd.line2),
          right: BorderSide(color: sd.line2),
          bottom: BorderSide(color: sd.line2, width: 2),
        ),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: sd.text)),
    );
  }
}

/// How Shift-drag works, on a desktop, where it does.
class ShiftDragTip extends StatelessWidget {
  const ShiftDragTip({super.key});

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return SdPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SdSectionTitle(words.fromAnyApp),
          const SizedBox(height: 12),
          Row(
            children: [
              const KeyCap('Shift'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('+', style: TextStyle(color: sd.muted)),
              ),
              Flexible(
                child: Text(
                  words.shiftDragAction,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(words.shiftDragExplain, style: TextStyle(color: sd.text2, height: 1.45)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KeyCap(mac ? 'Option' : 'Alt'),
              Text(words.toolsKeyHint, style: TextStyle(color: sd.muted, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

/// What Make it fit can do, before any file is in.
class FitPanel extends StatelessWidget {
  const FitPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final rows = [
      (Icons.chat_outlined, words.fitChat, words.fitChatNote),
      (Icons.mail_outline, words.fitEmail, words.fitEmailNote),
      (Icons.track_changes, words.fitSize, words.fitSizeNote),
      (Icons.badge_outlined, words.fitForm, words.fitFormNote),
      (Icons.document_scanner_outlined, words.fitScan, words.fitScanNote),
    ];
    return SdPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SdSectionTitle(words.modeFit),
          const SizedBox(height: 8),
          for (final (icon, title, note) in rows) _FitRow(icon: icon, title: title, note: note),
        ],
      ),
    );
  }
}

class _FitRow extends StatelessWidget {
  const _FitRow({required this.icon, required this.title, required this.note});

  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: sd.amberSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: sd.amberText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(note, style: TextStyle(fontSize: 12, color: sd.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The last few results, each with Undo where it can be reached.
class RecentPanel extends StatelessWidget {
  const RecentPanel({super.key, required this.items, required this.onOpenHistory, this.onUndo});

  final List<HistoryItem> items;
  final VoidCallback onOpenHistory;
  final void Function(HistoryItem item)? onUndo;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    return SdPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SdSectionTitle(words.recent)),
              TextButton(onPressed: onOpenHistory, child: Text(words.allHistory)),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(words.recentEmpty, style: TextStyle(color: sd.muted)),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _ExtTile(name: item.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _meta(words, item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: sd.muted),
                        ),
                      ],
                    ),
                  ),
                  if (onUndo != null && item.path != null && item.undoneAt == null)
                    IconButton(
                      tooltip: words.undo,
                      icon: Icon(Icons.undo, size: 18, color: sd.muted),
                      onPressed: () => onUndo!(item),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _meta(Words words, HistoryItem item) {
    final label = actionLabel(words, item.actionLabel);
    final before = item.bytesBefore;
    final sizes = before == null
        ? formatBytes(item.bytesAfter)
        : words.sizeChange(formatBytes(before), formatBytes(item.bytesAfter));
    return label.isEmpty ? sizes : '$label · $sizes';
  }
}

class _ExtTile extends StatelessWidget {
  const _ExtTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toUpperCase();
    final kind = FileKind.fromExtension(ext) ?? FileKind.unknown;
    final tile = switch (kind.family) {
      FileFamily.image => const Color(0xFF7FE0CB),
      FileFamily.pdf => const Color(0xFFF5B4AC),
      FileFamily.video || FileFamily.audio => const Color(0xFFB9C9F2),
      _ => const Color(0xFFC3D1CB),
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(10)),
      child: Text(
        ext.length > 4 ? ext.substring(0, 4) : ext,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F1A17)),
      ),
    );
  }
}

/// "Everything happens on this device."
class PrivacyPanel extends StatelessWidget {
  const PrivacyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return SdPanel(
      tint: (fill: sd.accentSoft, edge: sd.accentLine),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: sd.accentText, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.words.privacyNote, style: TextStyle(color: sd.text2, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// The kinds of file the app takes, under the dial.
class FamilyChips extends StatelessWidget {
  const FamilyChips({super.key});

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final label in [
          words.familyPhotos,
          words.familyPdf,
          words.familyMedia,
          words.familyArchives,
          words.familySubtitles,
        ])
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: sd.surface2, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: TextStyle(fontSize: 13, color: sd.muted)),
          ),
      ],
    );
  }
}

/// Convert, Make it fit and Tools, as tabs over the dial. Make it fit is amber, as its slices are.
class ModeTabs<T> extends StatelessWidget {
  const ModeTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.isFit,
  });

  final List<(T, String)> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool Function(T tab) isFit;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    // Shrinks rather than overflows on the narrowest phones.
    return FittedBox(fit: BoxFit.scaleDown, child: _tabs(sd));
  }

  Widget _tabs(SdColors sd) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: sd.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sd.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (tab, label) in tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Semantics(
                selected: tab == selected,
                button: true,
                child: TextButton(
                  onPressed: () => onSelected(tab),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: tab == selected
                        ? (isFit(tab) ? sd.amber : sd.accent)
                        : Colors.transparent,
                    foregroundColor: tab == selected
                        ? (isFit(tab) ? sd.amberInk : sd.accentInk)
                        : sd.text2,
                    textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
                  ),
                  child: Text(label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
