/// RAR archives kept in several files, which RAR calls volumes. Two ways of naming them are in use:
/// `photos.part1.rar`, `photos.part2.rar` and so on, or the older `photos.rar`, `photos.r00`,
/// `photos.r01`. Every part is a RAR from its first byte, so names say which belong together and in
/// what order, and the first header says whether a file is a part at all.
library;

/// What a RAR's first header says about it.
enum RarSplit {
  /// The whole archive, in one file.
  whole,

  /// The first of several parts.
  first,

  /// A part after the first.
  later,
}

const _rar5 = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00];
const _rar4 = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00];

bool _startsWith(List<int> bytes, List<int> start) {
  if (bytes.length < start.length) return false;
  for (var i = 0; i < start.length; i++) {
    if (bytes[i] != start[i]) return false;
  }
  return true;
}

/// Whether the RAR starting [head] is whole or one part of several, or null if [head] isn't the
/// start of a RAR or is too short to tell.
RarSplit? rarSplitOf(List<int> head) {
  if (_startsWith(head, _rar5)) return _rar5Split(head);
  if (_startsWith(head, _rar4)) {
    // The main header follows the 7-byte marker: CRC (2 bytes), type 0x73, then its flags.
    if (head.length < 12 || head[9] != 0x73) return null;
    final flags = head[10] | head[11] << 8;
    if (flags & 0x0001 == 0) return RarSplit.whole;
    // RAR 3 and later mark the first part. Before that none was marked, so such parts read as later
    // ones, which only changes what a failure says.
    return flags & 0x0100 != 0 ? RarSplit.first : RarSplit.later;
  }
  return null;
}

/// RAR 5: after the signature come the main header's CRC, its size, its type (1), its flags, and
/// then the archive's flags: 1 for a part, 2 when a part number follows, which every part but the
/// first has.
RarSplit? _rar5Split(List<int> head) {
  var at = _rar5.length + 4;
  int? vint() {
    var value = 0;
    for (var shift = 0; shift < 63; shift += 7) {
      if (at >= head.length) return null;
      final byte = head[at++];
      value |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return value;
    }
    return null;
  }

  if (vint() == null) return null; // header size
  if (vint() != 1) return null; // a main header
  final headerFlags = vint();
  if (headerFlags == null) return null;
  if (headerFlags & 0x0001 != 0 && vint() == null) return null; // extra area size
  if (headerFlags & 0x0002 != 0 && vint() == null) return null; // data size
  final archiveFlags = vint();
  if (archiveFlags == null) return null;
  if (archiveFlags & 0x0001 == 0) return RarSplit.whole;
  return archiveFlags & 0x0002 != 0 ? RarSplit.later : RarSplit.first;
}

/// The parts of one archive found among some files.
class PartSet {
  const PartSet({required this.name, required this.order, this.missing});

  /// What the whole archive is called: `photos.rar`.
  final String name;

  /// The parts, by their place in the names given, first part first.
  final List<int> order;

  /// The name of the first part that isn't there, such as `photos.part3.rar`, or null if none is
  /// missing before the last one found. A missing last part can't be told from names: reading
  /// the archive finds that.
  final String? missing;
}

final _newStyle = RegExp(r'^(.*)\.part(\d+)\.rar$', caseSensitive: false);
final _oldStyle = RegExp(r'^(.*)\.(rar|r(\d{2,3}))$', caseSensitive: false);

typedef _Part = ({int index, int number, String base, bool newStyle, int digits});

_Part? _partOf(int index, String name) {
  final newer = _newStyle.firstMatch(name);
  if (newer != null) {
    final digits = newer.group(2)!;
    return (
      index: index,
      number: int.parse(digits),
      base: newer.group(1)!,
      newStyle: true,
      digits: digits.length,
    );
  }
  final older = _oldStyle.firstMatch(name);
  if (older == null) return null;
  final digits = older.group(3);
  return (
    index: index,
    // photos.rar comes first, then photos.r00.
    number: digits == null ? 0 : int.parse(digits) + 1,
    base: older.group(1)!,
    newStyle: false,
    digits: digits?.length ?? 2,
  );
}

/// The archives among [names] that are in several parts, each with its parts in order, in the order
/// the first of each was given. Only sets of two or more: a part on its own stays as it is. Case
/// doesn't matter, as on Mac and Windows disks.
List<PartSet> findPartSets(List<String> names) {
  final groups = <String, List<_Part>>{};
  for (var i = 0; i < names.length; i++) {
    final part = _partOf(i, names[i]);
    if (part == null) continue;
    (groups['${part.newStyle} ${part.base.toLowerCase()}'] ??= []).add(part);
  }
  final sets = <PartSet>[];
  for (final group in groups.values) {
    final byNumber = <int, _Part>{};
    for (final part in group) {
      byNumber.putIfAbsent(part.number, () => part);
    }
    if (byNumber.length < 2) continue;
    final numbers = byNumber.keys.toList()..sort();
    final first = byNumber[numbers.first]!;
    String? missing;
    for (var n = first.newStyle ? 1 : 0; n <= numbers.last; n++) {
      if (byNumber.containsKey(n)) continue;
      missing = _nameOf(first, n);
      break;
    }
    sets.add(
      PartSet(
        name: '${first.base}.rar',
        order: [for (final n in numbers) byNumber[n]!.index],
        missing: missing,
      ),
    );
  }
  int earliest(PartSet set) => set.order.reduce((a, b) => a < b ? a : b);
  sets.sort((a, b) => earliest(a).compareTo(earliest(b)));
  return sets;
}

String _nameOf(_Part like, int number) {
  if (like.newStyle) return '${like.base}.part${'$number'.padLeft(like.digits, '0')}.rar';
  if (number == 0) return '${like.base}.rar';
  return '${like.base}.r${'${number - 1}'.padLeft(like.digits, '0')}';
}

/// The names of all the parts of the archive [name] belongs to, in order, found among the names of
/// the files beside it ([folder]), and the first one missing. Null if it isn't one of several
/// parts there.
({String name, List<String> parts, String? missing})? partsBeside(
  String name,
  List<String> folder,
) {
  final names = [name, ...folder.where((other) => other.toLowerCase() != name.toLowerCase())];
  for (final set in findPartSets(names)) {
    if (set.order.contains(0)) {
      return (name: set.name, parts: [for (final i in set.order) names[i]], missing: set.missing);
    }
  }
  return null;
}
