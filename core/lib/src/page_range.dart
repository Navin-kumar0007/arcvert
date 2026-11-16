import 'failures.dart';

/// Pages as people type them, such as `1-3, 7`, read into page numbers counted from 1, in the
/// order given, each once. Spaces don't matter. Throws a translated failure for anything that
/// isn't a page of a document of [total] pages.
List<int> parsePageRange(String text, int total) {
  final pages = <int>[];
  final seen = <int>{};
  final parts = text.split(',').map((part) => part.replaceAll(' ', '')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) throw Fail.noPagesChosen;
  for (final part in parts) {
    final match = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(part);
    if (match == null) throw Fail.badPageRange(part);
    final from = int.parse(match.group(1)!);
    final to = int.parse(match.group(2) ?? match.group(1)!);
    for (final page in [from, to]) {
      if (page < 1 || page > total) throw Fail.pageOutOfRange(page, total);
    }
    final step = from <= to ? 1 : -1;
    for (var page = from; ; page += step) {
      if (seen.add(page)) pages.add(page);
      if (page == to) break;
    }
  }
  return pages;
}

/// Page numbers written as [parsePageRange] reads them, with runs joined: 1, 2, 3, 7 is `1-3, 7`.
String formatPageRange(Iterable<int> pages) {
  final sorted = pages.toSet().toList()..sort();
  final parts = <String>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    parts.add(i == j ? '${sorted[i]}' : '${sorted[i]}-${sorted[j]}');
    i = j + 1;
  }
  return parts.join(', ');
}
