import 'package:flutter/foundation.dart';

/// How long one Shift-drag menu took to appear, in milliseconds, as the native menu measured it.
class MenuTiming {
  const MenuTiming({this.wait = 0, this.find = 0, this.ask = 0, this.draw = 0});

  /// From the check before the key was noticed, so the longest the key can have waited.
  final double wait;

  /// Windows finding the drag over its invisible window. Nothing on a Mac.
  final double find;

  /// Deciding what the menu offers.
  final double ask;

  /// Drawing it.
  final double draw;

  double get total => wait + find + ask + draw;

  /// What the native side sends, or null if it isn't that.
  static MenuTiming? fromWire(Object? wire) {
    if (wire is! Map) return null;
    double? read(String key) {
      final value = wire[key];
      return value is num ? value.toDouble() : null;
    }

    final parts = [read('wait'), read('find'), read('ask'), read('draw')];
    if (parts.any((part) => part == null || part < 0 || !part.isFinite)) return null;
    return MenuTiming(wait: parts[0]!, find: parts[1]!, ask: parts[2]!, draw: parts[3]!);
  }

  @override
  String toString() =>
      'wait ${wait.round()} + find ${find.round()} + ask ${ask.round()} + draw ${draw.round()} '
      '= ${total.round()} ms';
}

/// The last few menus' timings, in memory only, for Settings to show. The 1.0 plan asks for the
/// menu within 100 ms of the key, and only real drags on real computers can say.
class MenuSpeed extends ValueNotifier<List<MenuTiming>> {
  MenuSpeed() : super(const []);

  static final instance = MenuSpeed();

  static const kept = 50;

  void add(MenuTiming timing) {
    debugPrint('Shift-drag menu: $timing');
    final all = [...value, timing];
    value = List.unmodifiable(all.length > kept ? all.sublist(all.length - kept) : all);
  }

  /// The usual time (the median) and the slowest, rounded to whole milliseconds, or null before
  /// any menu has opened.
  ({int usual, int slowest, int count})? get summary {
    if (value.isEmpty) return null;
    final totals = [for (final timing in value) timing.total]..sort();
    final middle = totals.length ~/ 2;
    final usual = totals.length.isOdd ? totals[middle] : (totals[middle - 1] + totals[middle]) / 2;
    return (usual: usual.round(), slowest: totals.last.round(), count: totals.length);
  }
}
