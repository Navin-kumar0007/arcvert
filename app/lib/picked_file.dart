import 'dart:typed_data';

import 'package:radial_core/radial_core.dart';

/// A file the user chose. Only its start is read until it is needed, so choosing a very large
/// file costs nothing, and files we cannot convert are never read at all.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.size,
    required this.head,
    required this.read,
    this.webUrl,
    this.path,
    this.moreParts = const [],
    this.missingPart,
  });

  final String name;
  final int size;

  /// The start of the file, enough to identify it.
  final List<int> head;
  final Future<Uint8List> Function() read;

  /// In a browser, a `blob:` address for the file, so video can be read piece by piece.
  final String? webUrl;

  /// On a desktop, where the file is on disk.
  final String? path;

  /// A RAR in several parts is one file here, named for the whole archive, holding the first part:
  /// these are the others, in order.
  final List<PickedFile> moreParts;

  /// The name of a part that wasn't chosen with the others, which the job then says.
  final String? missingPart;
}

/// [files] with each RAR in several parts made one file, where its first part was, so the menu and
/// jobs treat it as the one archive it is. Its size is all the parts'. Anything else is left as it
/// was, including a part chosen on its own: a desktop finds the rest beside it.
List<PickedFile> joinArchiveParts(List<PickedFile> files) {
  final loose = [
    for (final file in files)
      if (file.moreParts.isEmpty && detectKind(file.head, fileName: file.name) == FileKind.rar)
        file
      else
        null,
  ];
  final sets = findPartSets([for (final file in loose) file?.name ?? '']);
  if (sets.isEmpty) return files;
  final replaced = <int, PickedFile>{};
  final gone = <int>{};
  for (final set in sets) {
    final parts = [for (final i in set.order) loose[i]!];
    final first = parts.first;
    replaced[set.order.reduce((a, b) => a < b ? a : b)] = PickedFile(
      name: set.name,
      size: parts.fold(0, (total, part) => total + part.size),
      head: first.head,
      read: first.read,
      webUrl: first.webUrl,
      path: first.path,
      moreParts: parts.sublist(1),
      missingPart: set.missing,
    );
    gone.addAll(set.order);
  }
  return [
    for (var i = 0; i < files.length; i++)
      if (replaced[i] case final joined?) joined else if (!gone.contains(i)) files[i],
  ];
}

/// What a drop brought: files dropped as they are, and files found inside dropped folders.
class DroppedFiles {
  const DroppedFiles({
    this.loose = const [],
    this.inFolders = const [],
    this.folders = 0,
    this.tooMany = false,
  });

  final List<PickedFile> loose;
  final List<PickedFile> inFolders;

  /// How many folders were dropped, as an empty one still needs an answer.
  final int folders;

  /// The folders held more than could be opened.
  final bool tooMany;
}

/// A finished result. Pictures are in memory. A video may be too large for that, so it is
/// already saved on a desktop, or brings its own way to save in a browser or on a phone.
class ConvertedFile {
  const ConvertedFile({
    required this.name,
    required this.size,
    this.inMemory,
    this.download,
    this.savedPath,
    this.cachedPath,
    this.note,
  });

  final String name;
  final int size;
  final PortableFile? inMemory;

  /// Saves a result that is not in memory. False if the user changed their mind.
  final Future<bool> Function()? download;

  /// Where the result already is, on a desktop.
  final String? savedPath;

  /// Where it waits on a phone until saved, which other apps can be given.
  final String? cachedPath;

  /// Anything the user should know about the result.
  final String? note;
}

/// Where a result was saved. Null in its place means the user changed their mind.
class SavedAs {
  const SavedAs({this.path});

  /// Null where a save has no path to give, as in a browser.
  final String? path;
}

/// Lets the screen stop a running conversion.
class ConvertControl {
  void Function()? cancel;

  /// Where a desktop's engines write results, or null for beside each original.
  String? outputFolder;
}
