import 'actions.dart';

/// The most slices one ring shows.
const menuSlots = 8;

/// Splits [actions] into pages for the radial menu. A page that has more after it holds one
/// slice fewer, leaving room for "More".
///
/// In the convert menu, format changes alternate with make-it-fit actions, so WhatsApp is on
/// the first page even though an image has many formats to offer. Learned ordering comes later.
List<List<RadialAction>> menuPages(List<RadialAction> actions, {int slots = menuSlots}) {
  if (slots < 2) throw ArgumentError.value(slots, 'slots', 'must be at least 2');
  final ordered = _interleaved(actions);
  if (ordered.length <= slots) return ordered.isEmpty ? const [] : [ordered];

  final pages = <List<RadialAction>>[];
  var start = 0;
  // Every page gets a More slice, the last one included, because More wraps back to the start.
  while (ordered.length - start > slots - 1) {
    pages.add(ordered.sublist(start, start + slots - 1));
    start += slots - 1;
  }
  if (start < ordered.length) pages.add(ordered.sublist(start));
  return pages;
}

List<RadialAction> _interleaved(List<RadialAction> actions) {
  final formats = actions.where((action) => action.isFormatChange).toList();
  final fits = actions.where((action) => !action.isFormatChange).toList();
  // Tools have no format changes, and format-only menus have no fits: both stay as they are.
  if (formats.isEmpty || fits.isEmpty) return actions;
  return [
    for (var i = 0; i < formats.length || i < fits.length; i++) ...[
      if (i < formats.length) formats[i],
      if (i < fits.length) fits[i],
    ],
  ];
}

/// [actions] with the ones used at least [often] times first, most used first, the rest in their
/// usual order. Ties keep the usual order too, so the menu only moves for a real habit.
List<RadialAction> orderByUse(List<RadialAction> actions, Map<String, int> uses, {int often = 3}) {
  int count(RadialAction action) => uses[action.id] ?? 0;
  final favourites = [
    for (final action in actions)
      if (count(action) >= often) action,
  ];
  // List.sort isn't stable, so ties are broken by where they were.
  final place = {for (var i = 0; i < actions.length; i++) actions[i]: i};
  favourites.sort((a, b) {
    final byUse = count(b).compareTo(count(a));
    return byUse != 0 ? byUse : place[a]!.compareTo(place[b]!);
  });
  return [
    ...favourites,
    for (final action in actions)
      if (count(action) < often) action,
  ];
}
